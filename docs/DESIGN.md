# SmartNotes Design System

SmartNotes uses the Neko visual profile: calm, print-flat Material 3 surfaces
that leave journal content and the capture action in focus.

## Color

| Role | Light | Dark |
|---|---|---|
| Signal red | `#C0392B` | `#E2543E` |
| Paper | `#FAFAF8` | `#0D0D0C` |
| Raised paper | `#FFFFFF` | `#181816` |
| Ink | `#141412` | `#F0EFEA` |
| Soft ink | `#57564F` | `#8F8E85` |

Signal red communicates a single primary, destructive, or live state. Widgets
obtain colors from `Theme.of(context).colorScheme`; only the theme defines raw
color values.

## Typography

Archivo is bundled for UI text at weights 400, 500, 600, and 700. Archivo Black
is bundled for display headings. Widgets select `TextTheme` roles and do not
set font families or arbitrary text sizes.

Reserve Archivo Black for display/headline roles, not controls or subsection
labels. Body text uses regular Archivo with 1.5 line height; subsection titles
use semibold Archivo. Button labels follow a compact 14sp scale with minimal
tracking so actions do not compete with the content.

## Shape And Depth

- Material 3 is used in light and dark schemes with `ThemeMode.system` on
  Android, iOS, and macOS. Desktop screens preserve the same bounded reading
  columns rather than stretching text across a wide window.
- Surfaces, controls, dialogs, cards, and sheets use a 12dp plate radius.
- Solid ink borders define interactive controls. Journal content uses whitespace
  and subtle `outlineVariant` dividers between days rather than ink rules per entry.
- Elevation and shadows remain at zero; tonal paper layers provide depth.

## Components

`AppTheme` provides themes for app bars, dividers, cards, dialogs, bottom
sheets, filled/elevated/outlined/text/icon buttons, FABs, inputs, snackbars,
and progress indicators. Screens should use these defaults before introducing
component-specific styling.

- Filled, outlined, and text buttons retain at least 48dp touch targets.
- Input focus uses a 2dp signal-red border; idle fields keep the ink border.
- Onboarding content is top-aligned in a 560dp reading column. Its primary
  action remains outside the scrolling content, above the safe-area inset.
- Settings use a bounded 640dp column with Privacy, Voice and local AI, and
  Your journal sections. App lock is a direct switch; destination rows show
  short summaries. Transcription groups audio language with its model catalog
  and expandable recovery actions. AI organization retains its optional catalog.
  Search model is a separate destination alongside Transcription and AI
  organization. Its Settings subtitle names the persisted active model and its
  readiness; never show an assumed default before selection is resolved. Its
  dedicated catalog page uses the same bounded layout as the other model pages,
   shared ModelSettingsPage chrome and ModelCatalogTile rows, like Transcription
   and AI organization. Rows share badges, metadata, information, description,
   status and trailing ModelCatalogActionButton controls, with 16dp between rows.
   Tap an installed row to select; search-model switches require rebuild
   confirmation. Explicit verification lives in its information dialog.
   Downloading never changes selection. Unavailable candidates stay in
  an initially collapsed section. The catalog is also reused during onboarding.
  Search by meaning contains explanations, index progress and maintenance only,
  with a Manage search model repair link when needed, not a model selector.
  Search by meaning and Backup and restore have dedicated pages; index repair
  lives under Advanced, and pending indexing actions appear only when needed.
  Labels and summaries wrap at compact widths and larger text scales.
- Model setup names each download and its size, with progress, cancellation,
  retry and verification. Optional larger 4B organization models have explicit
  memory/speed guidance
  and a scrollable Gemma terms confirmation before its download. All options
  retain the same shared catalog rows; smaller models remain recommended.
  Required speech and embedding models and the optional
  formatting-model step share the same compact row treatment; the formatting
  step can be skipped and remains available in Settings. Search settings expose
  pending/failed indexing and repair; partial semantic results carry an explicit
  incomplete-search notice.
- Note processing uses one silent, replace-in-place system notification and a
  matching status on the timeline entry. User-facing states are preparing
  transcription, transcribing, note ready while preparing search, and
  finalizing; expanded notification content may name the active local model.
  The notification opens the note and disappears after success or failure.
  Onboarding explains notification access before the system permission prompt;
  denial never blocks recording or processing and is not requested again.
- Search has one field: words refresh while typing, and explicit submission adds
  meaning-based matches without removing word results. Back leaves search; the
  field's clear action clears only the query. The borderless field sits in the
  top bar; a short hint and search feedback scroll with the results. Search
  covers all entry dates without a date filter.
- Entry details use a compact, title-free top bar with direct Edit, the magic
  wand, and overflow for Original transcription (when available) and Delete.
  The optional entry title and secondary date appear only in the content. The
  date row carries an outlined `Original · 1:34` action with a signal-red play
  triangle when audio exists; it opens a bottom-sheet player with play, seek,
  elapsed, and total time. Never put a player in the reading column. Keep the
  note unboxed in a bounded 640dp column.
  Audio never autoplays or resumes after an interruption; playback stops on
  background, sheet dismissal, navigation, deletion, and transcription retry.
  Missing audio does not block text.
- Saved notes and AI previews share content typography: bodyLarge prose and
  compact title-role Markdown headings. Untouched transcriptions stay literal.
  An intentionally empty edited note has an explicit empty state.
- Editing shows only the note body in an outlined editor, with a persistent
  small secondary Markdown hint and help icon inside its footer. The icon
  remains a 48dp touch target. Save opens optional title, subtitle,
  and entry date in a bottom sheet on compact screens or a dialog on larger
  screens; Save commits all fields. Dismissing the panel retains edits.
  Dirty Back offers Save (through the same metadata review),
  Discard, and Keep editing; local recovery drafts need explicit Resume/Discard.
- Typed capture is secondary: a neutral pencil in the journal top bar opens
  optional title and subtitle in a bottom sheet (a bounded dialog in wide
  windows). Continue opens the existing body editor with body focus; it does
  not create a timeline entry. The first Save requires nonblank body text and
  commits directly without repeating metadata review. Creation uses the same
  dirty-exit and local recovery protections as editing. The first saved body is
  literal text and remains available as Original text, including after edits or
  accepted AI formatting. Typed notes show no audio or retranscription controls;
  their AI actions remain post-save, optional, and preview-first. Recording keeps
  its existing dominant button and one-tap behavior. Initial setup is unchanged.
- The wand keeps its action bottom sheet and preview-first flow. The sheet opens
  before formatting-model readiness is known and shows a compact preparing or
  model-needed state inside it. Never hash model weights before presenting the
  sheet. Current/Preview controls compare against the generation source; proposed
  metadata is revealed only when selected. Apply/Discard stay outside the
  scrolling preview. Apply offers immediate, concurrency-checked Undo, not a
  revision-history promise.

## Journal Timeline

- In a single-pane window, keep the journal in a centered reading column no
  wider than 640dp. Preserve the phone layout and primary recording action.
- When both content minimums fit, use a quiet journal sidebar and a reading or
  editing pane. The sidebar is the expanded navigation; do not add a redundant
  rail of destinations to a journal with no folders or workspaces. Selected
  entries use a tonal surface, not a new accent or boxed card treatment.
- Capture is a workspace action: place its button at the bottom trailing corner
  of the window in split layouts, not inside the journal sidebar. Compact
  layouts retain the centered button. Recording dims and blocks both panes with
  a full-window overlay and waveform. Keep Stop at the same anchor and visible
  through fold/unfold, even if the feed becomes hidden. Avoid keyboard, safe-area,
  and hinge obstruction when positioning the controls. Reading and editing
  content reserve scroll clearance while the capture action is visible, so the
  button cannot obscure the final lines or editor footer.
- Start the reading pane with a neutral selection prompt, never an automatically
  opened private entry. Opening or closing a fold preserves the selected entry;
  compact presentation shows the active task, and Back returns to the list.
- Keep reading text bounded at 640dp within the available pane. Editing may
  expand to hide the sidebar, with an explicit control to restore it. Expansion
  and resizing preserve the same unsaved editor. Switching entries uses the
  existing Save/Discard/Keep editing confirmation, not automatic saving.
- Pane decisions use usable space and text scaling. Large text, keyboard
  occlusion, short windows, and separating folds may require one pane even in
  an otherwise wide window. Avoid obstructed hinge regions; a flat crease alone
  does not divide the page. No special tabletop interaction is introduced.
- Content leads: optional titles use `titleMedium` with at most two lines;
  previews use `bodyLarge` with at most three lines of the current note body,
  not generated subtitles. Untitled entries start directly with their text.
- Show the entry-date time once, beneath the preview, using `bodySmall`.
  Processing and error feedback share this secondary area and wrap as needed.
- Separate entries with whitespace and days with a subtle `outlineVariant` rule.
  Keep the existing flat surfaces, 12dp controls, and primary recording action.
- Search results replace the timeline while a query is active. Rank is the
  structure: entries keep retrieval order across dates instead of regrouping by
  day, each result carries its own entry date, and day headers return when the
  query is cleared.
- Keep previous text-search results readable during refresh with a slim progress
  indicator. Empty results appear only after the request completes. Search by
  meaning waits for an explicit submission, so its idle and remembering states
  are distinct from "no matches".
- Semantic results weaker than the calibrated distance are omitted rather than
  shown as near-misses; a query with only weak neighbours reads as no matches.
- Both retrieval engines rank and page across all entry dates.
  Pages append via Load more with a loading/retry/end state. Initial word results
  precede meaning results; later pages never move an already visible entry.
  Duplicate entries keep literal evidence when available. Query, loaded
  pages, and scroll survive a note round trip. A different query starts
  at the top. Diary/index changes ask for refresh before continuing stale offsets.
- Search previews show retrieval evidence rather than the beginning of a note.
  Word matches are highlighted in their surrounding passage; meaning-based
  results show the indexed passage with a "Related by meaning" label. Each
  passage identifies its source: title, current note, or original transcription.
  Passages crossing source boundaries name all sources. Only overflowing passages
  offer an inline expand/collapse action. Edited content never displays stale
  evidence as current text.
- Search errors keep any previous results readable and offer Retry, Edit search,
  word-search fallback, and direct search-model settings when repair is needed.
  Empty states use title/body typography with wording tips and an edit action.
- Preserve the scroll position on return from a note. Incoming entries wait
  until the reader returns to the top when they are reading older entries.

## Motion

- Use short ease-out transitions (180–240ms) for new entries and processing
  completion. Animate only newly received entries, never initial load or scrolling.
- Transition processing feedback and preview content in place; retain stable
  entry keys. Use standard Material route transitions for opening and returning.
- Respect the system's reduced-motion setting with immediate state changes,
  including recording-button visibility and state changes.

## System Bars And Insets

The app draws edge-to-edge. `AppSystemBars` supplies transparent status and
navigation bars with brightness-appropriate icons. Scrollable screens use
`AppInsets` helpers so content clears the system navigation inset.
