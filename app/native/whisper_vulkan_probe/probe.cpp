#include "whisper.h"
#include "ggml-backend.h"
#include "json.hpp"

#include <chrono>
#include <cstdio>
#include <fstream>
#include <memory>
#include <stdexcept>
#include <string>
#include <sys/resource.h>
#include <vector>
#include <algorithm>
#if SMARTNOTES_PROBE_VULKAN
#include <vulkan/vulkan.h>
#endif

using clock_type = std::chrono::steady_clock;
using json = nlohmann::ordered_json;
struct probe_error { const char * code; };

static double milliseconds(clock_type::time_point start) {
    return std::chrono::duration<double, std::milli>(clock_type::now() - start).count();
}

// The caller explicitly supplies public/synthetic fixtures, never journal audio.
// Suppress upstream path-bearing logs; retain only backend initialization evidence.
static bool vulkan_backend_initialized = false;
static void safe_log(enum ggml_log_level, const char * text, void *) {
    if (std::string(text).find("using Vulkan") != std::string::npos) {
        vulkan_backend_initialized = true;
    }
}

static json gpu_properties() {
#if SMARTNOTES_PROBE_VULKAN
    VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO};
    app.pApplicationName = "SmartNotes qualification probe";
    app.apiVersion = VK_API_VERSION_1_1;
    VkInstanceCreateInfo create{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
    create.pApplicationInfo = &app;
    VkInstance instance = VK_NULL_HANDLE;
    if (vkCreateInstance(&create, nullptr, &instance) != VK_SUCCESS) {
        throw probe_error{"vulkan_instance_failed"};
    }
    uint32_t count = 0;
    auto status = vkEnumeratePhysicalDevices(instance, &count, nullptr);
    std::vector<VkPhysicalDevice> devices(count);
    if (status == VK_SUCCESS && count) {
        status = vkEnumeratePhysicalDevices(instance, &count, devices.data());
    }
    json properties = json::array();
    if (status == VK_SUCCESS) {
        for (auto device : devices) {
            VkPhysicalDeviceProperties p{};
            vkGetPhysicalDeviceProperties(device, &p);
            uint32_t extension_count = 0;
            vkEnumerateDeviceExtensionProperties(device, nullptr, &extension_count, nullptr);
            std::vector<VkExtensionProperties> extensions(extension_count);
            vkEnumerateDeviceExtensionProperties(device, nullptr, &extension_count, extensions.data());
            auto has_extension = [&](const char * name) {
                return std::any_of(extensions.begin(), extensions.end(), [&](const auto & e) {
                    return std::string(e.extensionName) == name;
                });
            };
            VkPhysicalDeviceShaderFloat16Int8Features numeric{
                VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_FLOAT16_INT8_FEATURES};
            VkPhysicalDeviceShaderIntegerDotProductFeatures dot_feature{
                VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_INTEGER_DOT_PRODUCT_FEATURES};
            VkPhysicalDeviceShaderIntegerDotProductProperties dot_properties{
                VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_SHADER_INTEGER_DOT_PRODUCT_PROPERTIES};
            if (has_extension("VK_KHR_shader_integer_dot_product")) {
                numeric.pNext = &dot_feature;
                VkPhysicalDeviceProperties2 extended_properties{
                    VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_PROPERTIES_2};
                extended_properties.pNext = &dot_properties;
                vkGetPhysicalDeviceProperties2(device, &extended_properties);
            }
            VkPhysicalDeviceFeatures2 features{VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2};
            features.pNext = &numeric;
            vkGetPhysicalDeviceFeatures2(device, &features);
            properties.push_back({{"vendor_id", p.vendorID}, {"device_id", p.deviceID},
                                  {"driver_version", p.driverVersion},
                                  {"api_version", p.apiVersion}, {"name", p.deviceName},
                                  {"shader_float16", bool(numeric.shaderFloat16)},
                                  {"shader_int8", bool(numeric.shaderInt8)},
                                  {"cooperative_matrix_extension", has_extension("VK_KHR_cooperative_matrix")},
                                  {"integer_dot_product_extension", has_extension("VK_KHR_shader_integer_dot_product")},
                                  {"integer_dot_product_feature", bool(dot_feature.shaderIntegerDotProduct)},
                                  {"packed_signed_4x8_dot_accelerated", bool(dot_properties.integerDotProduct4x8BitPackedSignedAccelerated)},
                                  {"max_compute_shared_memory_bytes", p.limits.maxComputeSharedMemorySize},
                                  {"max_workgroup_invocations", p.limits.maxComputeWorkGroupInvocations}});
        }
    }
    vkDestroyInstance(instance, nullptr);
    if (properties.empty()) throw probe_error{"vulkan_device_missing"};
    return properties;
#else
    return json::array();
#endif
}

int main(int argc, char ** argv) {
    if (argc == 2 && std::string(argv[1]) == "--capabilities") {
        try {
            std::puts(json({{"devices", gpu_properties()}}).dump().c_str());
            return 0;
        } catch (...) {
            std::fprintf(stderr, "Vulkan capability inspection failed\n");
            return 1;
        }
    }
    if (argc != 6) {
        std::fprintf(stderr, "Expected model, mono 16kHz float32 PCM, language, threads, flash-attention\n");
        return 2;
    }
    whisper_log_set(safe_log, nullptr);
    ggml_log_set(safe_log, nullptr);
    try {
        const int threads = std::stoi(argv[4]);
        const std::string language = argv[3];
        if (threads < 1 || threads > 16 ||
            (language != "auto" && whisper_lang_id(language.c_str()) < 0)) {
            throw probe_error{"invalid_options"};
        }
        const auto total_start = clock_type::now();
        const auto probe_start = clock_type::now();
        const auto devices = gpu_properties();
        const double capability_probe_ms = milliseconds(probe_start);
        const auto read_start = clock_type::now();
        std::ifstream input(argv[2], std::ios::binary | std::ios::ate);
        const auto bytes = input.tellg();
        if (!input || bytes <= 0 || bytes % sizeof(float) || bytes > 30 * 60 * 16000 * sizeof(float)) {
            throw probe_error{"invalid_pcm"};
        }
        std::vector<float> samples(static_cast<size_t>(bytes) / sizeof(float));
        input.seekg(0);
        if (!input.read(reinterpret_cast<char *>(samples.data()), bytes)) {
            throw probe_error{"pcm_read_failed"};
        }
        const double pcm_read_ms = milliseconds(read_start);
        auto params = whisper_context_default_params();
        params.use_gpu = SMARTNOTES_PROBE_VULKAN;
        const std::string flash_option = argv[5];
        if (flash_option == "on") params.flash_attn = true;
        else if (flash_option == "off") params.flash_attn = false;
        else if (flash_option != "default") throw probe_error{"invalid_options"};
        // Match the plugin's context defaults; do not conflate GPU with FA tuning.
        const bool flash_attention = params.flash_attn;
        const auto load_start = clock_type::now();
        std::unique_ptr<whisper_context, decltype(&whisper_free)> context(
            whisper_init_from_file_with_params(argv[1], params), whisper_free);
        const double load_ms = milliseconds(load_start);
        if (!context) throw probe_error{"model_load_failed"};
        if (SMARTNOTES_PROBE_VULKAN && !vulkan_backend_initialized) {
            throw probe_error{"vulkan_not_initialized_cpu_fallback_rejected"};
        }
        auto full = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        full.n_threads = threads;
        full.language = language.c_str();
        full.translate = false;
        full.print_realtime = false;
        full.print_progress = false;
        full.print_timestamps = false;
        const auto inference_start = clock_type::now();
        if (whisper_full(context.get(), full, samples.data(), samples.size()) != 0) {
            throw probe_error{"inference_failed"};
        }
        const double inference_ms = milliseconds(inference_start);
        std::string transcript;
        for (int i = 0; i < whisper_full_n_segments(context.get()); ++i) {
            transcript += whisper_full_get_segment_text(context.get(), i);
        }
        // The pinned upstream API allocates this result with new. These values
        // are averages per native call, not totals across a long recording.
        std::unique_ptr<whisper_timings> timing_result(whisper_get_timings(context.get()));
        if (!timing_result) throw probe_error{"inference_failed"};
        const auto timings = *timing_result;
        timing_result.reset();
        const std::string detected_language = whisper_lang_str(whisper_full_lang_id(context.get()));
        const auto cleanup_start = clock_type::now();
        context.reset();
        const double cleanup_ms = milliseconds(cleanup_start);
        const double total_ms = milliseconds(total_start);
        rusage usage{};
        getrusage(RUSAGE_SELF, &usage);
        json report = {
            {"schema_version", 1}, {"runtime_version", whisper_version()},
            {"requested_backend", SMARTNOTES_PROBE_VULKAN ? "vulkan" : "cpu"},
            {"devices", devices}, {"capability_probe_ms", capability_probe_ms},
            {"vulkan_backend_initialized", vulkan_backend_initialized},
            {"offload_scope", "backend initialization confirmed; operation placement not profiled"},
            {"threads", threads}, {"flash_attention", flash_attention},
            {"language", language}, {"detected_language", detected_language},
            {"audio_seconds", samples.size() / 16000.0},
            {"pcm_read_ms", pcm_read_ms}, {"model_load_ms", load_ms},
            {"inference_ms", inference_ms}, {"cleanup_ms", cleanup_ms},
            {"native_total_ms", total_ms},
            {"encoder_ms", timings.encode_ms}, {"decoder_ms", timings.decode_ms},
            {"sampling_ms", timings.sample_ms}, {"peak_rss_kib", usage.ru_maxrss},
            {"subtiming_scope", "Whisper means per native call; not recording-level stage totals"},
            {"fixture_transcript", transcript},
        };
        std::puts(report.dump(-1, ' ', false, json::error_handler_t::replace).c_str());
        return 0;
    } catch (const probe_error & error) {
        std::puts(json({{"error", error.code}}).dump().c_str());
        return 1;
    } catch (...) {
        // Native errors can carry model/audio paths; never forward their message.
        std::fprintf(stderr, "Probe failed; configuration is not qualified\n");
        return 1;
    }
}
