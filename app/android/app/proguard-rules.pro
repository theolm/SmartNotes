# Room creates WorkManager's generated database through reflection before Flutter
# starts. R8 full mode must retain its no-argument constructor.
-keep class androidx.work.impl.WorkDatabase_Impl {
    public <init>();
}
