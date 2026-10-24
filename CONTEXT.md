# SmartNotes

SmartNotes is a personal voice journal. A person captures recordings and keeps a single journal on their device; optional AI turns speech into structured notes and helps retrieve past entries.

## Language

**Journal entry**: A saved recording and its note, or a note captured by typing, including the original source text, optional transformed content, title, subtitle, dates, and processing status. A recorded entry exists before transcription succeeds; a typed entry exists only after its nonblank body is saved. Neither needs AI transformation to be complete.
_Avoid_: Document, message, account-owned note.

**Recording**: The original captured audio, retained for playback and retry. Transcription uses speech at its original speed.

**Transcription**: The original speech represented as text on the device, without uploading audio. Once obtained, it is retained independently of formatting so a retry need not transcribe the recording again.

**Typed capture**: A secondary capture path for quiet or private moments. Optional title and subtitle precede the body editor; the first saved body is retained in the `transcription` field and presented as Original text. Later edits and accepted AI transformations do not overwrite it. Typing needs no recording, model, or network access; initial onboarding requirements remain unchanged.

**Speech model**: Downloaded recognition weights that enable offline transcription for supported spoken languages. Several may be installed; one compatible model must be active before completing setup.

**Active speech model**: The installed speech model explicitly selected for new transcriptions. A recommendation or an additional download does not replace this choice.

**Recommended speech model**: The catalog model suggested from the chosen audio language and an estimate of device capability. It guides selection but never becomes active without an explicit choice.

**Formatting model**: Optional downloaded language-model weights that generate an initial title and subtitle in the transcription's language, and organize or rewrite a note on the device when requested by the journaler. Several may be installed; one must be selected and available before generation can run. Missing weights or failed metadata generation never prevent a completed transcription.

**Active formatting model**: The installed formatting model explicitly selected for AI actions. A recommendation or an additional download does not replace this choice. Removing it requires selecting another model first.

**Recommended formatting model**: The catalog model suggested from an estimate of device capability. It guides selection but never becomes active, downloads, or switches without an explicit choice.

**Embedding model**: Downloaded retrieval-model weights that represent notes and queries for on-device search by meaning. It is required to finish setup, but its absence never prevents an existing journal from being read or searched by words.

**Current note**: The journaler's saved text, initially the original transcription and later any accepted edits or AI transformation. An intentionally empty edited note is distinct from an untouched transcription.

**AI action**: An optional transformation of the current note, such as an organized note, journal narrative, or key points. It must preserve source facts and is previewed before acceptance.

**AI draft**: A proposed transformation that is not part of the saved journal until the journaler explicitly applies it. Discarding it leaves the current note unchanged.

**Edit draft**: A recoverable, device-local editing buffer tied to the saved entry version it started from, or a new typed capture with no saved source. New captures retain a reserved entry ID for recovery without duplication. It is separate from the current note, AI drafts, search, and journal backups. Resuming requires an explicit choice; applying an existing-entry draft still checks for newer saved content. Draft recovery is best-effort and may not retain the last keystrokes before abrupt termination.

**Immediate Undo**: A session-scoped reversal of the most recently accepted AI transformation. It restores prior editable fields only if the accepted saved version is still current. It is not permanent revision history or restoration of the original recording/transcription.

**Processed audio**: The structured result of a note transformation: proposed title, subtitle, Markdown, and source text. It is a proposal, not an automatically saved journal entry.

**Entry date**: The user-facing date used to order and group entries. It may differ from the immutable creation date and the automatically maintained last-update date.

**Processing status**: The capture and transcription lifecycle: recording, processing, completed, or error. A completed entry needs no AI formatting; an optional transformation failure does not make it incomplete.

**Local journal**: The sole journal stored on this installation. There are no accounts, sign-in, ownership partitions, or cloud synchronization.
_Avoid_: User account, session, synced journal.

**Semantic index**: Derived representations of current notes and original transcriptions used to retrieve entries by meaning. It is disposable and can be rebuilt without deleting journal entries.

**Text search**: Offline retrieval using the words in saved notes and transcriptions.

**Semantic search**: On-device retrieval by meaning using a query representation compatible with the semantic index. Distant passages are not results, so a query about something absent from the journal can legitimately find nothing. Results are incomplete while notes await indexing or have failed indexing.

**Offline AI**: Transcription, note formatting, and semantic search performed on the device, without transmitting recordings, notes, or queries. Model installation and repair may require an internet connection.

**Journal backup**: A portable export containing notes and available original recordings, excluding downloaded AI models and the derived semantic index. Import restores entries by ID and replaces matching entries.

**App lock**: Optional local biometric or device-credential verification before showing the journal. It is not account authentication and does not encrypt the journal files.

**Settings**: Local preferences for language, theme, app lock, and AI configuration.
