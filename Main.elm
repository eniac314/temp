port module Main exposing (main)

import Audio exposing (Audio, AudioCmd, AudioData)
import Browser exposing (UrlRequest(..))
import Browser.Dom exposing (Viewport, focus)
import Browser.Events exposing (onAnimationFrame)
import Browser.Extra exposing (viewportDecoder)
import Browser.Navigation as Nav
import Codec
import Delay
import Dict exposing (..)
import Draggable
import Draggable.Events exposing (onDragBy, onDragStart)
import Duration
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input
import Element.Keyed as Keyed
import Element.Lazy exposing (lazy)
import Element.Region as Region
import File exposing (File)
import File.Select as FS
import Html
import Html.Attributes as HtmlAttr
import Html.Events as HtmlEvents exposing (onClick)
import Json.Decode as D
import Json.Encode as E
import Keyboard as K
import List.Extra
import Markdown.JapPreprocessor as JP
import Markdown.MarkdownEditor as MDE
import Markdown.MarkdownParser as MP
import Markdown.Renderer as MR
import Math.Vector2 as Vector2 exposing (Vec2, getX, getY)
import Pages.Adjectives as Adjectives
import Pages.Adjectives.AdjectivesQuiz as AQ
import Pages.Auth as Auth
import Pages.Blog as Blog
import Pages.Classical as Classical
import Pages.Classical.ClassicalQuizes as CQ
import Pages.FlashCards as FlashCards
import Pages.GrammarDict as GrammarDict
import Pages.JapaneseDictionary as JapaneseDictionary
import Pages.Kana as Kana
import Pages.Kanji as Kanji
import Pages.Kanji.KanjiEditor as KanjiEditor
import Pages.Kanji.KanjiQuiz as KanjiQuiz
import Pages.LegacyKana.Kana as LegacyKana
import Pages.MnnGrammar as MnnGrammar
import Pages.Presentation as Presentation
import Pages.Verbs as Verbs
import Pages.Verbs.VerbsFormsTable as VFT
import Pages.Verbs.VerbsQuiz as VQ
import Pages.Vocabulary as Vocabulary
import PdfElement
import Plugins.Decomposer as Decomposer
import Plugins.KanjiCanvas as KanjiCanvas
import Plugins.KanjiGifPlayer as KanjiGifPlayer
import Plugins.Logger exposing (..)
import Plugins.Mp3Player as Mp3Player
import Plugins.PdfReader as PdfReader
import Plugins.QCM as QCM
import Plugins.RichJapText as RJT
import Plugins.VocMemo as VocMemo
import Plugins.Whiteboard as Whiteboard
import Random.Pcg.Extended exposing (Seed, initialSeed, step)
import Routes exposing (..)
import Set
import Style.Helpers exposing (..)
import Style.Palette exposing (..)
import Task exposing (andThen, perform)
import Time exposing (..)
import Types exposing (..)
import Url
import Url.Parser exposing ((</>), int, map, oneOf, parse, s, string, top)
import Utils.Utils exposing (..)


port audioPortToJS : E.Value -> Cmd msg


port audioPortFromJS : (D.Value -> msg) -> Sub msg


port savePdfSimple : String -> Cmd msg



--initialModel : Model


init flags url key =
    let
        initialModel =
            { key = key
            , url = url
            , route = Home
            , appContainerScroll = 0
            , executeMsgOnNextFrame = Nothing
            , width = flags.width
            , height = flags.height
            , shiftDown = False
            , controlDown = False
            , seed = currentSeed
            , logs = Dict.empty
            , authPlugin = authPlugin
            , connexionDropped = 0
            , currentStudent = Nothing
            , clock = Time.millisToPosix flags.currentTime
            , mousePos = ( 0, 0 )
            , mouseTrackingOn = False
            , printModeOn = False
            , showingRomaji = False
            , localJapTokenizationAvailable = False
            , drag = Draggable.init
            , currentlyDragging = Nothing

            -- markdown editor
            , editingMarkdown = Nothing
            , originalMarkdown = Nothing
            , tokenizerStatus = Initial
            , savingMarkdownStatus = Initial

            -- vocabulary
            , vocabulary = Dict.empty
            , soundBank = Dict.empty
            , soundState = NotPlaying
            , expressionHidden = False
            , meaningHidden = False
            , pitchAccentsHidden = True
            , entryInput = Nothing
            , meaningInput = Nothing
            , readingInput = Nothing
            , pitchAccentInput = Nothing
            , editingVoc = Nothing
            , updatingWordEntry = Initial

            -- Grammar dict
            , grammarDict = Dict.empty
            , searchGrammarDictInput = Nothing
            , searchGrammarDictResults = []

            -- JMdict
            , jmDict = Dict.empty
            , jmDictEntriesUpdating = Dict.empty
            , currentJMdictBatchNumber = 1
            , jmDictSearchStatus = Initial
            , toJapSearchInput = Nothing
            , fromJapSearchInput = Nothing
            , jmDictSearchResults = Nothing
            , jmDictSearchLanguage = SearchInFrench
            , jmDictResultsLanguage = SearchEverything
            , jmDictKebs = ""
            , jmDictTmpKebs = []
            , examplesLoadingStatus = ( -1, Initial )

            -- Kanji
            , kanjidicSearching = Initial
            , kanjidicEntries = kanjidicEntries
            , hasGif = Set.empty
            , displayedKanjis = Dict.empty
            , preIndexed = preIndexed
            , saveLessonToPdfProgress = Nothing
            , kanjidicSearchInput = Nothing
            , customKanjiLessonTitleInput = Nothing
            , kanjiEditorNewCoreMeaningLang = Nothing
            , kanjiEditorNewMeaningLang = Nothing
            , editingKanji = Nothing
            , updatingKanjiStatus = Initial

            -- Kanji canvas
            , kanjiCanvasLoaded = False
            , kanjiCanvasOpen = False
            , recognizedKanji = []
            , lastSelectionBounds = Nothing

            -- Grammar
            , currentMaxLess = currentMaxLess
            , grammarLessons = Dict.empty

            -- Presentations
            , presentationRunning = False
            , presentationInitalState = Nothing
            , presentations = presentations

            -- Blog
            , blogEntries = blogEntries
            , privateBlogEntries = privateBlogEntries
            , membersBlogEntries = membersBlogEntries

            -- Legacy Kana
            , legacyKanaModel = legacyKana

            -- Pdf reader
            , pdfs = Dict.empty
            , pdfReaderPanelOpen = False
            , mp3PlayerVisible = True
            , pdfIndexVisible = True

            -- White board
            , boardOpen = False
            , sideBySide = False
            , mainContentFullScreen = mainContentFullScreen
            , boardInput = Nothing
            , realTimeTokenization = True
            , boardCurrentInputWithFurigana = Nothing
            , boardContent = []
            , currentlyEditing = Nothing
            , currentlyLoadingFurigana = Nothing
            , autoFurigana = True
            , whiteBoardFontSize = 18
            , removeRomajiInWhiteBoard = True
            , boardDetached = False
            , boardInputPosition = ( flags.width // 2 - (boardCurrentInputSize // 2), flags.height // 2 - 350 )
            , boardCurrentInputFontSize = 30
            , boardCurrentInputSize = boardCurrentInputSize
            , boardLoadingTranslation = Initial

            -- Decomposer
            , decomposerInput = Nothing
            , decomposerTranslatedInput = Nothing
            , decomposerRichInput = Nothing
            , decomposerKanaInput = Nothing
            , decomposerRomajiInput = Nothing
            , decomposerKanji = []
            , decomposerLoading = Initial
            , decomposerTranslationLoading = Initial

            -- Voc Memo
            , vocMemoOpen = False
            , vocMemoState = VocMemoExprInput
            , vocMemoVocList = []
            , vocMemoTitleInput = Nothing
            , vocMemoExpressionInput = Nothing
            , vocMemoReadingInput = Nothing
            , vocMemoMeaningInput = Nothing
            , vocMemoExampleInput = Nothing
            , vocMemoLoadingFurigana = Initial
            , vocMemoLoadingTranslation = Initial
            , vocMemoPosition = ( flags.width // 2 - 200, flags.height // 2 - 70 )

            -- Mp3 player
            , currentTrack = Nothing
            , currentPlayList = []
            , trackSelectorOpen = False
            , mp3PlaybackSpeed = 1

            -- flashcards
            , decks = Dict.empty
            , currentDueCards = Nothing
            , nextCardId = 0
            , nextDeckId = 0
            , deckNameInput = Nothing
            , editedCardBuffer = Nothing
            , flashCardPluginSaving = Initial
            , flashCardPluginInitialLoadingDone = False
            , reversedDecksSelected = Set.empty
            , decksToBeLoadedForGeneralReview = Set.empty
            , editingNewCard = False
            , showingWholeDeck = False
            , showingAnswer = False
            , audioAvailable = False
            , newCardsFront = False

            -- verbsQuiz
            , verbsQuiz = VQ.loading flags.currentTime

            -- verbsTable
            , verbsTableConfig =
                VFT.defaultConfig
                    (min (flags.width - 200) 1000)

            -- adjectivesQuiz
            , adjectivesQuiz = AQ.loading flags.currentTime

            -- Classical quizes
            , inflectedFormQuiz = CQ.loading flags.currentTime

            -- QCM
            , qcmBank = QCM.transitivityQcmBank flags.currentTime

            -- Kanji quizzes
            , kanjiReadingQuizzes = KanjiQuiz.yomuRenshus
            , kanjiWritingQuizzes = KanjiQuiz.kakuRenshus
            , kanjiQuizFontSize = 20
            , kanjiQuizRevealEverything = False

            -- RichJapText
            , richJapTexts = Dict.empty
            }

        ( model, cmds, audioCmds ) =
            case
                parse
                    (routeParser initialModel)
                    url
            of
                Just res ->
                    applyRoute initialModel res

                _ ->
                    ( initialModel, Nav.pushUrl key "/", Audio.cmdNone )

        ( seed, seedExtension ) =
            flags.seedInfo

        currentSeed =
            initialSeed seed seedExtension

        ( authPlugin, authCmd ) =
            Auth.init
                { addLogMsg = AddLog
                , outMsg = AuthPluginMsg
                }
                flags.authStatus

        preIndexed =
            case D.decodeString (Codec.decoder Kanji.preIndexedCodec) flags.preIndexed of
                Ok pi ->
                    pi

                Err _ ->
                    Kanji.defPreIndexed

        ( kanjidicEntries, getKeysCmd ) =
            case D.decodeString (D.list D.string) flags.kanjiKeys of
                Ok keys ->
                    ( List.map (\k -> ( k, Nothing )) keys
                        |> Dict.fromList
                    , Cmd.none
                    )

                Err _ ->
                    ( Dict.empty, Kanji.getKanjiKeys )

        currentMaxLess =
            case D.decodeString (D.list D.string) flags.mnnGrammarEntries of
                Ok mge ->
                    List.length mge

                _ ->
                    0

        blogEntries =
            case D.decodeString (D.list D.string) flags.blogEntries of
                Ok bes ->
                    List.map (\be -> ( be, Nothing )) bes
                        |> Dict.fromList

                _ ->
                    Dict.empty

        privateBlogEntries =
            case D.decodeString (D.list D.string) flags.privateBlogEntries of
                Ok bes ->
                    List.map (\be -> ( be, Nothing )) bes
                        |> Dict.fromList

                _ ->
                    Dict.empty

        membersBlogEntries =
            case D.decodeString (D.list D.string) flags.membersBlogEntries of
                Ok bes ->
                    List.map (\be -> ( be, Nothing )) bes
                        |> Dict.fromList

                _ ->
                    Dict.empty

        presentations =
            case D.decodeString (D.list D.string) flags.presentations of
                Ok ps ->
                    List.map (\p -> ( p, Nothing )) ps
                        |> Dict.fromList

                _ ->
                    Dict.empty

        ( legacyKana, legacyKanaCmds ) =
            LegacyKana.init key

        mainContentFullScreen =
            Auth.isAdmin <| Auth.getLogInfo authPlugin

        boardCurrentInputSize =
            if mainContentFullScreen then
                1000

            else
                800
    in
    ( model
    , Cmd.batch
        [ getKeysCmd
        , cmds
        , Cmd.map LegacyKanaMsg legacyKanaCmds
        , authCmd
        , if Auth.isLogged <| Auth.getLogInfo authPlugin then
            if Auth.isAdmin <| Auth.getLogInfo authPlugin then
                Maybe.map atLoginAdminCmds (Auth.getUserName authPlugin)
                    |> Maybe.withDefault Cmd.none

            else if Auth.isUser <| Auth.getLogInfo authPlugin then
                Maybe.map atLoginUserCmds (Auth.getUserName authPlugin)
                    |> Maybe.withDefault Cmd.none

            else
                Cmd.none

          else
            Cmd.none

        --, Kanji.getKanjidicXml
        --, JapaneseDictionary.getKebIndex
        , JP.testLocalhostTokenizerCmd
        ]
    , audioCmds
    )


atLoginAdminCmds username =
    Cmd.batch
        [ PdfReader.getPdfConfigs
        , GrammarDict.getGrammarDict
        , Blog.getPrivateBlogIndex
        , FlashCards.getDecksAndNextIds username
        ]


atLoginUserCmds username =
    Cmd.batch
        [ FlashCards.getDecksAndNextIds username ]


update : AudioData -> Msg -> Model -> ( Model, Cmd Msg, AudioCmd Msg )
update ad msg model =
    case msg of
        -- Misc
        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    , Audio.cmdNone
                    )

                External url ->
                    ( model
                    , Nav.load url
                    , Audio.cmdNone
                    )

        UrlChanged url ->
            case parse (routeParser model) url of
                Just res ->
                    applyRoute { model | url = url, printModeOn = False } res

                Nothing ->
                    ( model, Nav.pushUrl model.key "/", Audio.cmdNone )

        AppContainerScrolled { scene, viewport } ->
            ( { model
                | appContainerScroll = viewport.y
              }
            , Cmd.none
            , Audio.cmdNone
            )

        Resized w h ->
            ( { model
                | width = w
                , height = h
              }
            , Cmd.none
            , Audio.cmdNone
            )

        DoOnNextFrame ->
            case model.executeMsgOnNextFrame of
                Just toDo ->
                    update ad toDo { model | executeMsgOnNextFrame = Nothing }

                _ ->
                    ( model, Cmd.none, Audio.cmdNone )

        AddLog log ->
            let
                ( logHash, newSeed ) =
                    hashLog model.seed log

                newLogs =
                    safeInsert (\k -> k + 1) logHash ( log, False ) model.logs
            in
            ( { model
                | logs = newLogs
                , seed = newSeed
              }
            , Cmd.none
            , Audio.cmdNone
            )

        AuthPluginMsg authPluginMsg ->
            let
                logInfo =
                    Auth.getLogInfo newAuthPlugin

                ( newAuthPlugin, authPluginCmds, mbPluginResult ) =
                    Auth.update
                        { addLogMsg = AddLog
                        , outMsg = AuthPluginMsg
                        }
                        authPluginMsg
                        model.authPlugin
            in
            ( { model
                | authPlugin = newAuthPlugin
                , connexionDropped =
                    if (model.connexionDropped == 0) && (mbPluginResult == Just (PluginData LoggedOut)) then
                        1

                    else if (model.connexionDropped > 0) && (mbPluginResult == Just (PluginData LoggedOut)) then
                        model.connexionDropped + 1

                    else
                        0
              }
            , Cmd.batch <|
                [ authPluginCmds
                , if mbPluginResult == Just PluginQuit then
                    Nav.pushUrl model.key
                        "/"

                  else
                    Cmd.none
                , if not (Auth.isLogged <| Auth.getLogInfo model.authPlugin) then
                    if Auth.isAdmin <| Auth.getLogInfo newAuthPlugin then
                        Maybe.map atLoginAdminCmds (Auth.getUserName newAuthPlugin)
                            |> Maybe.withDefault Cmd.none

                    else if Auth.isUser <| Auth.getLogInfo newAuthPlugin then
                        Maybe.map atLoginUserCmds (Auth.getUserName newAuthPlugin)
                            |> Maybe.withDefault Cmd.none

                    else
                        Cmd.none

                  else if
                    -- reload data when impersonating user
                    (Auth.isAdmin <| Auth.getLogInfo model.authPlugin)
                        && (Auth.isUser <| Auth.getLogInfo newAuthPlugin)
                  then
                    Maybe.map atLoginUserCmds (Auth.getUserName newAuthPlugin)
                        |> Maybe.withDefault Cmd.none

                  else
                    Cmd.none
                ]
            , Audio.cmdNone
            )

        ShiftDown ->
            ( { model | shiftDown = True }, Cmd.none, Audio.cmdNone )

        ShiftUp ->
            ( { model | shiftDown = False }, Cmd.none, Audio.cmdNone )

        KeyboardMsg keyMsg ->
            let
                pressedKeys =
                    K.update keyMsg []

                controlDown =
                    List.member K.Control pressedKeys

                altDown =
                    List.member K.Alt pressedKeys

                vocMemoOpen =
                    if controlDown then
                        not model.vocMemoOpen

                    else
                        model.vocMemoOpen

                boardDetached =
                    if altDown then
                        not model.boardDetached

                    else
                        model.boardDetached

                newModel =
                    { model
                        | controlDown = controlDown
                        , vocMemoOpen = vocMemoOpen
                        , boardDetached = boardDetached
                        , vocMemoTitleInput =
                            if vocMemoOpen && model.vocMemoTitleInput == Nothing then
                                Just <| VocMemo.defaultDeckName model

                            else
                                model.vocMemoTitleInput
                    }

                --( m, c, a ) =
                --    if newModel.vocMemoOpen then
                --        VocMemo.keyboardMsg newModel keyMsg
                --    else
                --        ( newModel, Cmd.none, Audio.cmdNone )
            in
            if newModel.vocMemoOpen || newModel.boardDetached then
                let
                    ( m, c, a ) =
                        if newModel.vocMemoOpen then
                            VocMemo.keyboardMsg newModel keyMsg

                        else
                            ( newModel, Cmd.none, Audio.cmdNone )
                in
                ( m
                , Cmd.batch
                    [ c
                    , if newModel.vocMemoOpen && not model.vocMemoOpen then
                        Task.attempt (\_ -> NoOp) (Browser.Dom.focus "vocMemoInput")

                      else if newModel.boardDetached && not model.boardDetached then
                        Task.attempt (\_ -> NoOp) (Browser.Dom.focus "whiteBoardCurrentInput")

                      else
                        Cmd.none
                    ]
                , a
                )

            else if model.boardOpen then
                -- prevent whiteboard key input conflicting with underneath content
                ( newModel, Cmd.none, Audio.cmdNone )

            else if routeIsUsingPdfReader model then
                PdfReader.keyboardMsg newModel keyMsg

            else
                case model.route of
                    Presentations _ ->
                        Presentation.keyboardMsg newModel keyMsg

                    Kana _ ->
                        ( newModel, Kana.keyboardMsg newModel keyMsg, Audio.cmdNone )

                    FlashCards fcRoute ->
                        FlashCards.keyboardMsg newModel fcRoute keyMsg

                    JMDict _ ->
                        JapaneseDictionary.keyboardMsg newModel keyMsg

                    Verbs VerbsQuizRoute ->
                        Verbs.keyboardMsg newModel keyMsg

                    Classical ClassicalInflectedFormQuiz ->
                        Classical.keyboardMsg newModel keyMsg

                    Adjectives AdjectivesIndex ->
                        Adjectives.keyboardMsg newModel keyMsg

                    Kanjidic KanjidicIndex ->
                        Kanji.keyboardMsg newModel keyMsg

                    _ ->
                        ( newModel, Cmd.none, Audio.cmdNone )

        GotTime t ->
            ( { model
                | clock = t
                , soundState =
                    if Mp3Player.playbackFinished ad model then
                        NotPlaying

                    else
                        model.soundState
              }
            , Cmd.none
            , Audio.cmdNone
            )

        GotMousePos x y ->
            ( { model | mousePos = ( x, y ) }, Cmd.none, Audio.cmdNone )

        TogglePrintMode ->
            ( { model | printModeOn = not model.printModeOn }
            , Cmd.none
            , Audio.cmdNone
            )

        ToggleShowingRomaji ->
            ( { model | showingRomaji = not model.showingRomaji }
            , Cmd.none
            , Audio.cmdNone
            )

        SavePdfSimple id ->
            ( model, savePdfSimple id, Audio.cmdNone )

        TokenizeJapStrings ( xs, handler ) ->
            JP.tokenizeJapStrings model ( xs, handler )

        GotJapStringTokens handler res ->
            JP.gotJapStringTokens model handler res

        LocalhostTokenizationResult res ->
            case res of
                Ok _ ->
                    ( { model | localJapTokenizationAvailable = True }
                    , Cmd.none
                    , Audio.cmdNone
                    )

                _ ->
                    ( { model | localJapTokenizationAvailable = False }
                    , Cmd.none
                    , Audio.cmdNone
                    )

        NoOp ->
            ( model, Cmd.none, Audio.cmdNone )

        -- MarkdownEditor
        ToggleEditMarkdown mt ->
            MDE.toggleEditMarkdown model mt

        MarkdownEditorInput str ->
            MDE.markdownEditorInput model str

        SaveMarkdown target path markdown ->
            MDE.saveMarkdown model target path markdown

        MarkdownSaved target res ->
            MDE.markdownSaved model target res

        -- Vocabulary
        GetVocabulary ->
            ( model, Vocabulary.requests GotVocabulary, Audio.cmdNone )

        GotVocabulary n res ->
            Vocabulary.gotVocabulary model n res

        LoadAndPlayAudio path expression ->
            ( model, Cmd.none, Audio.loadAudio (SoundLoaded True expression) path )

        SoundLoaded play e result ->
            case result of
                Ok sound ->
                    ( { model | soundBank = Dict.insert e sound model.soundBank }
                    , if play then
                        Task.perform (PressedPlayAndGotTime e) Time.now

                      else
                        Cmd.none
                    , Audio.cmdNone
                    )

                _ ->
                    ( model, Cmd.none, Audio.cmdNone )

        PressedPlay name ->
            ( model, Task.perform (PressedPlayAndGotTime name) Time.now, Audio.cmdNone )

        PressedPlayAndGotTime name time ->
            ( { model | soundState = Playing name time }, Cmd.none, Audio.cmdNone )

        ToggleHideJapanese ->
            Vocabulary.toggleHideJapanese model

        ToggleHideFrench ->
            Vocabulary.toggleHideFrench model

        ToggleHideJapaneseWord n ->
            Vocabulary.toggleHideJapaneseWord model n

        ToggleHideFrenchWord n ->
            Vocabulary.toggleHideFrenchWord model n

        ToggleHidePitchAccents ->
            Vocabulary.toggleHidePitchAccents model

        EditWordEntry index ->
            Vocabulary.selectEntry model index

        VocExprInput s ->
            Vocabulary.vocExprInput model s

        VocReadingInput s ->
            Vocabulary.vocReadingInput model s

        VocMeaningInput s ->
            Vocabulary.vocMeaningInput model s

        PitchAccentInput s ->
            Vocabulary.pitchAccentInput model s

        UpdateWordEntry ->
            Vocabulary.updateWordEntry model

        WordEntryUpdated res ->
            Vocabulary.wordEntryUpdated model res

        GetKanjisDataForVocabulary we ->
            Vocabulary.getKanjisDataForVocabulary model we

        GotKanjisDataForVocabulary res ->
            Vocabulary.gotKanjisDataForVocabulary model res

        -- Grammar dict
        GotGrammarDictIndex res ->
            GrammarDict.gotGrammarDictIndex model res

        SearchGrammarDict s ->
            GrammarDict.search model s

        -- JMdict
        StartLoadingJMdictXmlIntoMysql ->
            ( model, JapaneseDictionary.getJMdictXml model.currentJMdictBatchNumber, Audio.cmdNone )

        GotKebIndex res ->
            JapaneseDictionary.gotKebIndex model res

        GotJMdictXml res ->
            JapaneseDictionary.gotJMdictXml model res

        JMdictEntryUpdated n res ->
            JapaneseDictionary.jmDictEntryUpdated model n res

        JMdictEntriesUpdated ns res ->
            JapaneseDictionary.jmDictEntriesUpdated model ns res

        FromJapSearchInput searchStr ->
            JapaneseDictionary.fromJapSearchInput model searchStr

        FromJapSearch ->
            JapaneseDictionary.fromJapSearch model

        ToJapSearchInput searchStr ->
            JapaneseDictionary.toJapSearchInput model searchStr

        ToJapSearch ->
            JapaneseDictionary.toJapSearch model

        GotJMdictSearchResults res ->
            JapaneseDictionary.gotJMdictSearchResults model res

        GetTatoebaExamples ent_seq examplePrompt ->
            JapaneseDictionary.getTatoebaExamples model ent_seq examplePrompt

        GotTatoebaExamples ent_seq res ->
            JapaneseDictionary.gotTatoebaExamples model ent_seq res

        SetSearchResultsLanguage l ->
            JapaneseDictionary.setSearchResultsLanguage model l

        JMdictConvertRomajiInput s ->
            JapaneseDictionary.convertRomajiInput model s

        SetSearchLanguage l ->
            JapaneseDictionary.setSearchLanguage model l

        -- Kanji
        GotKanjidicXml res ->
            Kanji.gotKanjidicXml model res

        GotKodanshaKanji data ->
            ( Kanji.addKodanshaKanjiData model data, Cmd.none, Audio.cmdNone )

        GotKanjiDecompositions res ->
            Kanji.gotKanjiDecompositions model res

        GotKanjidicKeys res ->
            Kanji.gotKanjidicKeys model res

        GotKanjidicEntry res ->
            Kanji.gotKanjidicEntry model res

        GotKanjidicEntries res ->
            Kanji.gotKanjidicEntries model res

        LoadLibgif id ->
            KanjiGifPlayer.loadLibgif model id

        GifLoaded s ->
            ( { model | hasGif = Set.insert s model.hasGif }, Cmd.none, Audio.cmdNone )

        LibGifLoaded id length frame ->
            KanjiGifPlayer.libGifLoaded model id length frame

        PlayPauseGif id ->
            KanjiGifPlayer.playPauseGif model id

        ResetGif id ->
            KanjiGifPlayer.resetGif model id

        PlayGifFrame id n ->
            KanjiGifPlayer.playGifFrame model id n

        SetKanjiDisplay id kd ->
            KanjiGifPlayer.setKanjiDisplay model id kd

        SetKanjiMeaningLang kanji lang ->
            Kanji.setKanjiMeaningLang model kanji lang

        UpdateKanji ks ->
            Kanji.updateKanji model ks

        SaveLessonToPdf class ->
            ( model
            , Kanji.savePdf class
            , Audio.cmdNone
            )

        SaveLessonToPdfProgress res ->
            Kanji.saveLessonToPdfProgress model res

        KanjidicSearchInput concat s ->
            Kanji.kanjidicSearchInput model concat s

        CustomKanjiLessonTitleInput s ->
            Kanji.customKanjiLessonTitleInput model s

        SearchKanjidic ->
            Kanji.searchKanjidic model

        -- Kanji Editor
        EditKanji k ->
            KanjiEditor.editKanji model k

        EditCoreMeanings index s ->
            KanjiEditor.editCoreMeanings model index s

        EditMeanings index s ->
            KanjiEditor.editMeanings model index s

        AddKanjiNewCoreMeaning lang ->
            KanjiEditor.addNewCoreMeaning model lang

        AddKanjiNewMeaning lang ->
            KanjiEditor.addNewMeaning model lang

        RemoveKanjiCoreMeaning index ->
            KanjiEditor.removeCoreMeaning model index

        RemoveKanjiMeaning index ->
            KanjiEditor.removeMeaning model index

        SwapKanjiCoreMeaning index swapUp ->
            KanjiEditor.swapKanjiCoreMeaning model index swapUp

        SwapKanjiMeaning index swapUp ->
            KanjiEditor.swapKanjiMeaning model index swapUp

        SetEditedKanjiCoreMeaningLang lang ->
            KanjiEditor.setNewCoreMeaningLang model lang

        SetEditedKanjiMeaningLang lang ->
            KanjiEditor.setNewMeaningLang model lang

        UpdateEditedKanji k ->
            KanjiEditor.updateKanji model k

        KanjiUpdated k res ->
            KanjiEditor.kanjiUpdated model k res

        -- KanjiCanvas
        GetLastSelectionBounds id ->
            KanjiCanvas.getLastSelectionBounds model id

        GotLastSelectionBounds res ->
            KanjiCanvas.gotLastSelectionBounds model res

        ToggleKanjiCanvas ->
            KanjiCanvas.toggleKanjiCanvas model

        InitializeKanjiCanvas ->
            KanjiCanvas.initialize model

        EraseKanjiCanvas ->
            KanjiCanvas.erase model

        DeleteLastKanjiCanvas ->
            KanjiCanvas.deleteLast model

        RecognizeKanjiCanvas ->
            KanjiCanvas.recognize model

        ProcessMessagefromKanjiCanvas res ->
            KanjiCanvas.processMessagefromKanjiCanvas model res

        -- Grammar
        GetMnnGrammar n ->
            ( model, Cmd.none, Audio.cmdNone )

        GotMnnGrammar n res ->
            MnnGrammar.gotMnnGrammar model n res

        --Blog
        GotBlogEntry s res ->
            Blog.gotBlogEntry model s res

        GotPrivateBlogIndex res ->
            Blog.gotPrivateBlogIndex model res

        GotMembersBlogEntry s res ->
            Blog.gotMembersBlogEntry model s res

        GotPrivateBlogEntry s res ->
            Blog.gotPrivateBlogEntry model s res

        -- Presentations
        GotPresentation s res ->
            Presentation.gotPresentation model s res

        OpenSlide n ->
            Presentation.openSlide model n

        AdvancePresentation ->
            Presentation.advancePresentation model

        ResetPresentation ->
            Presentation.resetPresentation model

        -- LegacyKana
        LegacyKanaMsg legacyKanaMsg ->
            let
                ( newLegacyKana, cmd ) =
                    LegacyKana.update legacyKanaMsg model.legacyKanaModel
            in
            ( { model
                | legacyKanaModel = newLegacyKana
              }
            , Cmd.map LegacyKanaMsg cmd
            , Audio.cmdNone
            )

        -- Pdf reader
        OpenClick ->
            PdfReader.openClick model

        PdfOpened file ->
            PdfReader.pdfOpened model file

        GotPdfConfigs res ->
            PdfReader.gotPdfConfigs model res

        PdfExtracted name string ->
            PdfReader.pdfExtracted model name string

        PdfMsg ms ->
            PdfReader.pdfMsg model ms

        PrevPage name ->
            PdfReader.prevPage model name

        GoToPage name page ->
            PdfReader.goToPage model name page

        NextPage name ->
            PdfReader.nextPage model name

        ZoomChanged name string ->
            PdfReader.zoomChanged model name string

        OkError name ->
            PdfReader.okError model name

        TogglePdfReaderPanel ->
            PdfReader.togglePdfReaderPanel model

        ToggleMp3PlayerVisible ->
            PdfReader.toggleMp3PlayerVisible model

        TogglePdfIndexVisible ->
            PdfReader.togglePdfIndexVisible model

        TogglePdfIndexEntry name id ->
            PdfReader.togglePdfIndexEntry model name id

        -- White board
        ToggleBoard ->
            Whiteboard.toggleBoard model

        ToggleSideBySide ->
            Whiteboard.toggleSideBySide model

        ToggleMainContentFullScreen ->
            let
                mbConfig =
                    PdfReader.getPdfConfig model
            in
            case mbConfig of
                Just config ->
                    PdfReader.zoomChanged { model | mainContentFullScreen = not <| model.mainContentFullScreen }
                        config.src
                        (config.zoom
                            + (if model.mainContentFullScreen then
                                -1

                               else
                                1
                              )
                            |> String.fromFloat
                        )

                Nothing ->
                    ( { model | mainContentFullScreen = not <| model.mainContentFullScreen }
                    , Cmd.none
                    , Audio.cmdNone
                    )

        ToggleMouseTracking ->
            ( { model | mouseTrackingOn = not model.mouseTrackingOn }
            , Cmd.none
            , Audio.cmdNone
            )

        WhiteBoardInput s ->
            Whiteboard.whiteBoardInput model s

        AddToBoard ->
            Whiteboard.addToBoard model

        EditBoardItem n ->
            Whiteboard.editBoardItem model n

        AddBracketsToBoard ->
            Whiteboard.addBracketsToBoard model

        ClearBoard ->
            Whiteboard.clearBoard model

        RemoveFromBoard n ->
            Whiteboard.removeFromBoard model n

        SwapBoardItemUp n ->
            Whiteboard.swapBoardItemUp model n

        SwapBoardItemDown n ->
            Whiteboard.swapBoardItemDown model n

        ToggleAutoFurigana ->
            Whiteboard.toggleAutoFurigana model

        GetFurigana index input ->
            Whiteboard.getFurigana model index input

        --AddFurigana n original res ->
        --    Whiteboard.addFurigana model n original res
        CurrentBoardTokenizationResult inputs res ->
            Whiteboard.currentBoardTokenizationResult model inputs res

        IncreaseWhiteBoardFontSize ->
            Whiteboard.increaseWhiteBoardFontSize model

        DecreaseWhiteBoardFontSize ->
            Whiteboard.decreaseWhiteBoardFontSize model

        ToggleRomajiInWhiteBoard ->
            Whiteboard.toggleRomajiInWhiteBoard model

        ChangeCurrentBoardSize n ->
            Whiteboard.changeCurrentBoardSize model n

        ChangeCurrentBoardFontSize n ->
            Whiteboard.changeCurrentBoardFontSize model n

        RequestWhiteboardTranslation ->
            Whiteboard.requestWhiteboardTranslation model

        WhiteboardTranslationInput res ->
            Whiteboard.whiteboardTranslationInput model res

        -- Decomposer
        DecomposerInput s ->
            Decomposer.decomposerInput model s

        DecomposerGetFurigana s ->
            Decomposer.getFurigana model s

        DecomposerTranslate s ->
            Decomposer.translateInput model s

        DecomposerGotTranslation res ->
            Decomposer.gotTranslation model res

        --VocMemo
        VocMemoAddCustomString s ->
            VocMemo.vocMemoAddCustomString model s

        ResetVocMemo ->
            VocMemo.resetVocMemo model

        ToggleVocMemo ->
            VocMemo.toggleVocMemo model

        VocMemoExpressionInput expression ->
            VocMemo.vocMemoExpressionInput model expression

        VocMemoValidateExpressionInput ->
            VocMemo.vocMemoValidateExpressionInput model

        VocMemoReadingInput reading ->
            VocMemo.vocMemoReadingInput model reading

        VocMemoMeaningInput meaning ->
            VocMemo.vocMemoMeaningInput model meaning

        VocMemoTranslationInput res ->
            VocMemo.vocMemoTranslationInput model res

        AddWordToVocMemo ->
            VocMemo.addWordToVocMemo model

        VocMemoDeckTitleInput title ->
            VocMemo.vocMemoDeckTitleInput model title

        VocMemoExamInput example ->
            VocMemo.vocMemoExampleInput model example

        VocMemoSaveDeck ->
            VocMemo.vocMemoSaveDeck model

        VocMemoMakeAnkiDeck ->
            VocMemo.vocMemoMakeAnkiDeck model

        SetVocMemoStateTo state ->
            VocMemo.setVocMemoStateTo model state

        OnDragBy vec2 ->
            case model.currentlyDragging of
                Just "vocMemo" ->
                    let
                        ( x, y ) =
                            model.vocMemoPosition

                        ( dx, dy ) =
                            ( Vector2.getX vec2, Vector2.getY vec2 )
                    in
                    ( { model | vocMemoPosition = ( round (toFloat x + dx), round (toFloat y + dy) ) }
                    , Cmd.none
                    , Audio.cmdNone
                    )

                Just "whiteBoardCurrentInput" ->
                    let
                        ( x, y ) =
                            model.boardInputPosition

                        ( dx, dy ) =
                            ( Vector2.getX vec2, Vector2.getY vec2 )
                    in
                    ( { model | boardInputPosition = ( round (toFloat x + dx), round (toFloat y + dy) ) }
                    , Cmd.none
                    , Audio.cmdNone
                    )

                _ ->
                    ( model, Cmd.none, Audio.cmdNone )

        DragMsg dragMsg ->
            let
                ( m, c ) =
                    Draggable.update dragConfig dragMsg model
            in
            ( m, c, Audio.cmdNone )

        StartDragging id ->
            ( { model | currentlyDragging = Just id }, Cmd.none, Audio.cmdNone )

        -- Mp3 player
        Mp3PlayerPressedPlayPause name ->
            Mp3Player.mp3PlayerPressedPlayPause model name

        Mp3PlayerPressedPlayPauseAndGotTime name time ->
            Mp3Player.mp3PlayerPressedPlayPauseAndGotTime model name time

        Mp3PlayerSelectTrack name ->
            Mp3Player.selectTrack model name

        Mp3PlayerSkipToNextTrack ->
            Mp3Player.skipToNextTrack model

        Mp3PlayerSkipToPrevTrack ->
            Mp3Player.skipToPrevTrack model

        Mp3PlayerSkipTo duration ->
            Mp3Player.skipTo model duration

        Mp3PlayerSkipToNextBookmark ->
            Mp3Player.skipToNextBookmark model

        Mp3PlayerSkipToPrevBookmark ->
            Mp3Player.skipToPrevBookmark model

        Mp3PlayerToggleTrackSelector ->
            Mp3Player.toggleTrackSelector model

        -- Flashcards
        CreateMnnDeck lessNum ->
            FlashCards.createMnnDeck model lessNum

        CreateKanjiLessonDeck lessName kanjiList ->
            FlashCards.createKanjiLessonDeck model lessName kanjiList

        CreateKanjiVocabDeck lessName lessons kanjis ->
            FlashCards.createKanjiVocabDeck model lessName kanjis lessons

        CreateReverseDeck deckId ->
            FlashCards.createReverseDeck model deckId

        CreateNewCustomDeck ->
            FlashCards.createNewCustomDeck model

        ConfirmDeckCreation deck res ->
            FlashCards.confirmDeckCreation model deck res

        GotDecksAndNextIds owner res ->
            FlashCards.gotDecksAndNextIds model owner res

        GotDeckCards owner id res ->
            FlashCards.gotDeckCards model owner id res

        --PickDeck showingWholeDeck id ->
        --    FlashCards.pickDeck model showingWholeDeck id
        LoadDueCards deckId time ->
            FlashCards.loadDueCards model deckId time

        LoadDueCardsFromAllDecks time ->
            FlashCards.loadDueCardsFromAllDecks model time

        ResetDeck id ->
            FlashCards.resetDeck model id

        SetShowingPolicy id sp ->
            FlashCards.setShowingPolicy model id sp

        SetFuriganaPolicy id fp ->
            FlashCards.setFuriganaPolicy model id fp

        DeleteDeck id ->
            FlashCards.deleteDeckRequest model id

        DeleteCard deckId id ->
            FlashCards.deleteCardRequest model deckId id

        ConfirmCardDeletion deckId id res ->
            FlashCards.confirmCardDeletion model deckId id res

        ConfirmDeckUpdate id deck res ->
            FlashCards.confirmDeckUpdate model id deck res

        ConfirmDeckDeletion id res ->
            FlashCards.confirmDeckDeletion model id res

        ToggleSkip deckId index ->
            FlashCards.toggleSkip model deckId index

        SkipCard ->
            FlashCards.skipCard model

        ToggleReversed deckId index ->
            FlashCards.toggleReversed model deckId index

        ToggleShowFurigana deckId index ->
            FlashCards.toggleFurigana model deckId index

        ToggleAudioAvailable ->
            FlashCards.toggleAudioAvailable model

        SetNewCardsFront b ->
            FlashCards.setNewCardsFront model b

        ShowAnswer ->
            FlashCards.showAnswer model

        RequestTimeAndAnswer answer ->
            FlashCards.requestTimeAndAnswer model answer

        AnswerCard answer time ->
            FlashCards.answerCard model answer time

        ConfirmAnsweredCardUpdate updatedDeck updatedDueCards res ->
            FlashCards.confirmAnsweredCardUpdate model updatedDeck updatedDueCards res

        ConfirmCardUpdate updatedDeck res ->
            FlashCards.confirmCardUpdate model updatedDeck res

        ToggleReversedDeck id ->
            FlashCards.toggleReversedDeck model id

        DeckNameInput name ->
            FlashCards.deckNameInput model name

        SaveDeckName deckId ->
            FlashCards.saveDeckName model deckId

        SelectCard deckId id ->
            FlashCards.selectCard model deckId id

        CreateNewCard deckId ->
            FlashCards.createNewCard model deckId

        CardExpressionInput expression ->
            FlashCards.cardExpressionInput model expression

        CardMeaningInput meaning ->
            FlashCards.cardMeaningInput model meaning

        CardReadingInput reading ->
            FlashCards.cardReadingInput model reading

        CardExampleInput example ->
            FlashCards.cardExampleInput model example

        SaveEditedCard deckId ->
            FlashCards.saveEditedCard model deckId

        -- Verbs Table
        ToggleVerbsTableOption opt ->
            VFT.toggleVTOpt model opt

        --Verbs quiz
        VerbsQuiz quizMsg ->
            let
                ( newQuiz, cmd ) =
                    VQ.update
                        (Time.posixToMillis model.clock)
                        quizMsg
                        model.verbsQuiz
            in
            ( { model
                | verbsQuiz = newQuiz
              }
            , cmd
            , Audio.cmdNone
            )

        --Adjectives quiz
        AdjectivesQuiz quizMsg ->
            let
                ( newQuiz, cmd ) =
                    AQ.update
                        (Time.posixToMillis model.clock)
                        quizMsg
                        model.adjectivesQuiz
            in
            ( { model
                | adjectivesQuiz = newQuiz
              }
            , cmd
            , Audio.cmdNone
            )

        -- Classical Quizes
        InflectedFormQuiz ifQuizMsg ->
            let
                ( newQuiz, cmd ) =
                    CQ.update
                        (Time.posixToMillis model.clock)
                        ifQuizMsg
                        model.inflectedFormQuiz
            in
            ( { model
                | inflectedFormQuiz = newQuiz
              }
            , cmd
            , Audio.cmdNone
            )

        -- QCM
        AnswerQCM id index choice ->
            QCM.answerQCM model id index choice

        SetQCMRandomState id b ->
            QCM.setQCMRandomState model id b

        -- Kanji quizzes
        CheckKanjiReadingQuizAnswer lessonName questionIndex index ->
            KanjiQuiz.checkKanjiReadingQuizAnswer model lessonName questionIndex index

        CheckKanjiWritingQuizAnswer lessonName questionIndex index ->
            KanjiQuiz.checkKanjiWritingQuizAnswer model lessonName questionIndex index

        ChangeKanjiQuizFontSize n ->
            ( { model | kanjiQuizFontSize = model.kanjiQuizFontSize + n }
            , Cmd.none
            , Audio.cmdNone
            )

        ToggleKanjiQuizRevealEveryThing ->
            ( { model | kanjiQuizRevealEverything = not model.kanjiQuizRevealEverything }
            , Cmd.none
            , Audio.cmdNone
            )

        -- RichJapText
        RichJapTextMsg id rjtMsg ->
            case Dict.get id model.richJapTexts of
                Just rjtModel ->
                    let
                        ( newRJTModel, rjtCmd ) =
                            RJT.update (RichJapTextMsg id) rjtMsg rjtModel
                    in
                    ( { model | richJapTexts = Dict.insert id newRJTModel model.richJapTexts }
                    , rjtCmd
                    , Audio.cmdNone
                    )

                Nothing ->
                    ( model, Cmd.none, Audio.cmdNone )



--dragConfig : Draggable.Config String Msg
--dragConfig =
--    Draggable.basicConfig OnDragBy


dragConfig : Draggable.Config String Msg
dragConfig =
    Draggable.customConfig
        [ onDragBy (\( dx, dy ) -> Vector2.vec2 dx dy |> OnDragBy)
        , onDragStart StartDragging
        ]



-------------------------------------------------------------------------------


gigView =
    el
        [ padding 15 ]
    <|
        el
            [ centerX, Background.tiled "/images/nami.png" ]
        <|
            el
                [ width (px 1280)
                , height (px 769)
                , Background.color (rgba255 52 73 114 0.6)
                ]
                (column
                    [ spaceEvenly
                    , padding 50
                    , Font.color white
                    , width fill
                    , height fill
                    ]
                    [ el [ centerX, Font.size 95 ] (text "和仏訳")
                    , el
                        [ width (px 500)
                        , height (px 500)
                        , centerX
                        , Background.uncropped "/images/翻譯Logo 2.png"
                        ]
                        Element.none
                    , el [ centerX, Font.size 70 ] (text "Traduction Japonais - Français")
                    ]
                )


view : AudioData -> Model -> Browser.Document Msg
view audiodata model =
    { title = ""
    , body =
        [ Html.node "style"
            []
            [ if model.printModeOn then
                Html.text <|
                    """
                .kanjiLink{
                    color: black;
                }
                """

              else
                Html.text <|
                    """
                body {
                    overflow: hidden;
                }

                .kanjiLink{
                    color: black;
                }
                """
            ]

        --, Element.layout [] gigView
        , if model.presentationRunning then
            Element.layout [] <| Routes.mainContentView audiodata model

          else if model.printModeOn then
            Element.layout
                [ Events.onClick TogglePrintMode ]
            <|
                column
                    [ width fill
                    , height fill
                    , centerX
                    , Background.color white
                    , scrollbarY
                    ]
                    [ Routes.mainContentView audiodata model
                    ]

          else
            Element.layout
                [ htmlAttribute <| HtmlAttr.id ""
                , Background.tiled "/images/background.png"
                , width fill
                , height fill
                , htmlAttribute <| HtmlAttr.id "page"
                , htmlAttribute <|
                    HtmlAttr.style "background-position"
                        ("0px " ++ String.fromFloat (model.appContainerScroll / -7) ++ "px")
                , if Auth.isAdmin (Auth.getLogInfo model.authPlugin) then
                    inFront <|
                        Whiteboard.view model

                  else
                    noAttr
                , if Auth.isAdmin (Auth.getLogInfo model.authPlugin) then
                    inFront <|
                        PdfReader.leftPanelView audiodata model

                  else
                    noAttr
                , if Auth.isAdmin (Auth.getLogInfo model.authPlugin) && model.vocMemoOpen then
                    inFront <|
                        VocMemo.view model

                  else
                    noAttr
                , if Auth.isAdmin (Auth.getLogInfo model.authPlugin) && model.boardDetached then
                    inFront <|
                        Whiteboard.boardCurrentInputWithFuriganaView model

                  else
                    noAttr
                , if model.mouseTrackingOn then
                    inFront <|
                        el
                            [ Background.uncropped "/images/pointer.svg"
                            , htmlAttribute <| HtmlAttr.style "pointer-events" "none"
                            , width (px 35)
                            , height (px 35)
                            , moveRight (Tuple.first model.mousePos - 15)
                            , moveDown (Tuple.second model.mousePos - 15)
                            ]
                            Element.none

                  else
                    noAttr
                ]
                (el
                    [ Background.tiled "/images/foreground.png"
                    , width fill
                    , height fill
                    , clip
                    ]
                 <|
                    el
                        [ width fill
                        , height (minimum model.height fill)
                        , scrollbarY
                        , htmlAttribute <| HtmlAttr.id "scrollableContainer"
                        , onScroll AppContainerScrolled

                        --, chromeHeightFix
                        ]
                    <|
                        el
                            [ Background.tiled "/images/nami.png"
                            , if
                                model.sideBySide
                                    && model.boardOpen
                                    && Auth.isAdmin (Auth.getLogInfo model.authPlugin)
                              then
                                alignLeft

                              else
                                centerX
                            , if model.sideBySide && model.boardOpen then
                                moveRight 35

                              else
                                noAttr
                            , if model.mainContentFullScreen then
                                width (px <| model.width - 145)

                              else
                                width (maximum 1200 fill)
                            , height fill

                            --, htmlAttribute <| HtmlAttr.id "scrollableContainer"
                            --, onScroll AppContainerScrolled
                            ]
                        <|
                            column
                                [ Background.color (rgba255 52 73 114 0.6)
                                , width fill
                                , height fill
                                , padding 15
                                , spacing 15
                                ]
                                [ mainMenu model
                                , column
                                    [ width fill
                                    , height fill
                                    , centerX
                                    , Background.color white
                                    ]
                                    [ Routes.mainContentView audiodata model
                                    ]
                                , footer model
                                ]
                )
        ]
    }


mainMenuWidth model =
    if model.mainContentFullScreen then
        model.width - 175

    else
        min model.width 1200 - 30


mainMenuHeight model =
    30


mainMenu model =
    row
        [ width (px <| mainMenuWidth model)
        , height (px <| mainMenuHeight model)
        , scrollbarX
        , spacing 15
        , centerX
        ]
        [ link
            [ Background.tiled "/images/namiG.gif"
            , paddingEach { sides | left = 15 }
            , Font.color white
            , mouseOver [ Font.color (rgb255 40 186 123) ]
            ]
            { url = "/"
            , label =
                el
                    [ Font.size 16
                    , Background.color (rgb255 52 73 114)
                    , paddingXY 7 5
                    ]
                    (text "Accueil")
            }
        , link
            [ Background.tiled "/images/namiG.gif"
            , paddingEach { sides | left = 15 }
            , Font.color white
            , mouseOver [ Font.color (rgb255 40 186 123) ]
            ]
            { url = "/coursJaponais"
            , label =
                el
                    [ Font.size 16
                    , Background.color (rgb255 52 73 114)
                    , paddingXY 7 5
                    ]
                    (text "Cours de japonais")
            }
        , case Auth.getLogInfo model.authPlugin of
            LoggedIn _ ->
                link
                    [ Background.tiled "/images/namiG.gif"
                    , paddingEach { sides | left = 15 }
                    , Font.color white
                    , mouseOver [ Font.color (rgb255 40 186 123) ]
                    , alignRight
                    ]
                    { url = "/flashcards/index"
                    , label =
                        el
                            [ Font.size 16
                            , Background.color (rgb255 52 73 114)
                            , paddingXY 7 5
                            ]
                            (text "Flashcards")
                    }

            _ ->
                Element.none
        , link
            [ Background.tiled "/images/namiG.gif"
            , paddingEach { sides | left = 15 }
            , Font.color white
            , mouseOver [ Font.color (rgb255 40 186 123) ]
            , alignRight
            ]
            { url = "/auth"
            , label =
                el
                    [ Font.size 16
                    , if model.connexionDropped > 0 then
                        Background.color lightRed

                      else
                        Background.color (rgb255 52 73 114)
                    , paddingXY 7 5
                    ]
                    (text <|
                        case Auth.getLogInfo model.authPlugin of
                            LoggedIn _ ->
                                "Mon compte"

                            LoggedOut ->
                                "Se connecter"
                    )
            }
        ]


footerWidth model =
    if model.mainContentFullScreen then
        model.width - 175

    else
        min model.width 1200 - 30


footerHeight model =
    30


footer model =
    let
        content =
            row
                [ width (px <| mainMenuWidth model)
                , height (px <| mainMenuHeight model)
                , scrollbarX
                , spacing 15
                ]
                [ link
                    [ Background.tiled "/images/namiG.gif"
                    , paddingEach { sides | left = 15 }
                    , Font.color white
                    , mouseOver [ Font.color (rgb255 40 186 123) ]
                    ]
                    { url = "/mentionsLegales"
                    , label =
                        el
                            [ Font.size 16
                            , Background.color (rgb255 52 73 114)
                            , paddingXY 7 5
                            ]
                            (text "Mentions légales")
                    }
                , link
                    [ Background.tiled "/images/namiG.gif"
                    , paddingEach { sides | left = 15 }
                    , Font.color white
                    , alignRight
                    , mouseOver [ Font.color (rgb255 40 186 123) ]
                    ]
                    { url = "/references"
                    , label =
                        el
                            [ Font.size 16
                            , Background.color (rgb255 52 73 114)
                            , paddingXY 7 5
                            ]
                            (text "Références")
                    }
                ]
    in
    case Auth.getLogInfo model.authPlugin of
        LoggedIn { role } ->
            if Auth.isAdmin (Auth.getLogInfo model.authPlugin) then
                Element.none

            else
                content

        LoggedOut ->
            content


type alias Flags =
    { currentTime : Int
    , width : Int
    , height : Int
    , kanjiKeys : String
    , preIndexed : String
    , blogEntries : String
    , membersBlogEntries : String
    , privateBlogEntries : String
    , mnnGrammarEntries : String
    , presentations : String
    , authStatus : String
    , seedInfo : ( Int, List Int )
    }


main : Program Flags (Audio.Model Msg Model) (Audio.Msg Msg)
main =
    Audio.applicationWithAudio
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = UrlClicked
        , onUrlChange = UrlChanged
        , audio = audio
        , audioPort = { toJS = audioPortToJS, fromJS = audioPortFromJS }
        }


audio audioData model =
    case model.soundState of
        NotPlaying ->
            Audio.silence

        Playing name time ->
            case Dict.get name model.soundBank of
                Just s ->
                    let
                        ad =
                            Audio.audioDefaultConfig
                    in
                    Audio.audioWithConfig { ad | playbackRate = model.mp3PlaybackSpeed } s time

                Nothing ->
                    Audio.silence

        PlayingStartedAt name time offset ->
            case Dict.get name model.soundBank of
                Just s ->
                    let
                        ad =
                            Audio.audioDefaultConfig
                    in
                    Audio.audioWithConfig { ad | startAt = offset, playbackRate = model.mp3PlaybackSpeed } s time

                Nothing ->
                    Audio.silence

        Paused name time ->
            Audio.silence



--FadingOut name startTime stopTime ->
--    case Dict.get name model.soundBank of
--        Just s ->
--            Audio.audio s startTime
--                |> Audio.scaleVolumeAt [ ( stopTime, 1 ), ( Duration.addTo stopTime (Duration.seconds 2), 0 ) ]
--        Nothing ->
--            Audio.silence


subscriptions audiodata model =
    let
        isLongAudioPlaying =
            case ( model.route, model.soundState ) of
                ( MinnaNoNihongo (MnnManual _), Playing _ _ ) ->
                    True

                ( MinnaNoNihongo (MnnManual _), PlayingStartedAt _ _ _ ) ->
                    True

                _ ->
                    False
    in
    Sub.batch
        [ KanjiGifPlayer.libgifMessage
            (\d ->
                case D.decodeValue KanjiGifPlayer.libgifMessageDecoder d of
                    Ok { id, message, length, frame } ->
                        case message of
                            "Loading done" ->
                                LibGifLoaded id length frame

                            "frameNbr" ->
                                LibGifLoaded id length frame

                            _ ->
                                NoOp

                    _ ->
                        NoOp
            )
        , Kanji.savePdfProgress
            (D.decodeValue
                (D.map2 (\d t -> { done = d, total = t })
                    (D.field "done" D.int)
                    (D.field "total" D.int)
                )
                >> SaveLessonToPdfProgress
            )
        , if model.executeMsgOnNextFrame /= Nothing then
            onAnimationFrame (always DoOnNextFrame)

          else
            Sub.none
        , KanjiCanvas.fromKanjiCanvas ProcessMessagefromKanjiCanvas
        , KanjiCanvas.fromInputField GotLastSelectionBounds
        , Browser.Events.onResize Resized
        , PdfReader.pdfreceive
        , Auth.subscriptions (model.connexionDropped > 0 && model.connexionDropped <= 20) AuthPluginMsg model.authPlugin

        --, Routes.keyboardSub model
        , if Auth.isAdmin (Auth.getLogInfo model.authPlugin) then
            Sub.map KeyboardMsg K.subscriptions

          else
            Routes.keyboardSub model
        , if isLongAudioPlaying then
            Time.every 100 GotTime

          else
            Sub.none
        , if model.mouseTrackingOn then
            Browser.Events.onMouseMove
                (D.map2
                    GotMousePos
                    (D.field "pageX" D.float)
                    (D.field "pageY" D.float)
                )

          else
            Sub.none
        , case model.route of
            FlashCards _ ->
                Time.every 1000 GotTime

            _ ->
                Sub.none
        , if model.vocMemoOpen || model.boardDetached then
            Draggable.subscriptions DragMsg model.drag

          else
            Sub.none
        ]


onScroll : (Browser.Dom.Viewport -> msg) -> Attribute msg
onScroll handler =
    HtmlEvents.stopPropagationOn "scroll"
        (D.map handler Browser.Extra.viewportDecoder
            |> D.map (\msg -> ( msg, True ))
        )
        |> htmlAttribute
