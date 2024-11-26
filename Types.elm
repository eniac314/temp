module Types exposing (..)

--import Pages.Auth as Auth

import Audio exposing (LoadError, Source)
import Browser exposing (UrlRequest)
import Browser.Dom exposing (Viewport)
import Browser.Navigation as Nav exposing (Key)
import Dict exposing (Dict)
import Draggable
import Duration exposing (Duration)
import Element exposing (Element)
import File exposing (File)
import Http exposing (Error)
import Json.Decode as D
import Keyboard exposing (Key)
import List.Nonempty as NE exposing (Nonempty)
import Math.Vector2 as Vector2 exposing (Vec2)
import Pages.LegacyKana.Kana as LegacyKana
import PdfElement
import Random
import Random.Pcg.Extended exposing (Seed)
import RollingList as RL
import Set
import SpacedRepetition.SMTwoAnki as SR
import StateMachine exposing (Allowed, State(..))
import Time exposing (Posix)
import Url exposing (Url)



-------------------------------------------------------------------------------
-- Main


type alias Model =
    { key : Nav.Key
    , url : Url.Url
    , route : Route
    , appContainerScroll : Float
    , executeMsgOnNextFrame : Maybe Msg
    , width : Int
    , height : Int
    , shiftDown : Bool
    , controlDown : Bool
    , authPlugin : Auth
    , connexionDropped : Int
    , currentStudent : Maybe String
    , seed : Seed
    , logs : Dict.Dict Int ( Log, Bool )
    , clock : Posix
    , mousePos : ( Float, Float )
    , mouseTrackingOn : Bool
    , printModeOn : Bool
    , showingRomaji : Bool
    , localJapTokenizationAvailable : Bool
    , drag : Draggable.State String
    , currentlyDragging : Maybe String

    -- markdown editor
    , editingMarkdown : Maybe MarkdownEditorTarget
    , originalMarkdown : Maybe ( MarkdownEditorTarget, Article )
    , tokenizerStatus : Status
    , savingMarkdownStatus : Status

    -- vocabulary
    , vocabulary : Dict Int Lesson
    , soundBank : Dict String Audio.Source
    , soundState : SoundState
    , expressionHidden : Bool
    , meaningHidden : Bool
    , pitchAccentsHidden : Bool
    , entryInput : Maybe String
    , meaningInput : Maybe String
    , readingInput : Maybe String
    , pitchAccentInput : Maybe String
    , editingVoc : Maybe Int
    , updatingWordEntry : Status

    -- Grammar dict
    , grammarDict : Dict String GrammarDictEntry
    , searchGrammarDictInput : Maybe String
    , searchGrammarDictResults : List String

    -- JMdict
    , jmDict : Dict Int JapDictEntry
    , jmDictEntriesUpdating : Dict Int Status
    , currentJMdictBatchNumber : Int
    , jmDictSearchStatus : Status
    , toJapSearchInput : Maybe String
    , fromJapSearchInput : Maybe String
    , jmDictSearchResults : Maybe (List JapDictEntry)
    , jmDictSearchLanguage : JMdictLanguage
    , jmDictResultsLanguage : JMdictLanguage
    , jmDictTmpKebs : List String
    , jmDictKebs : String
    , examplesLoadingStatus : ( Int, Status )

    -- Kanji
    , kanjidicSearching : Status
    , kanjidicEntries : Dict String (Maybe KanjidicEntry)
    , hasGif : Set.Set String
    , displayedKanjis :
        Dict
            String
            ( KanjiDisplay
            , { lang : String }
            , Maybe
                { source : String
                , length : Int
                , currentFrame : Int
                , playing : Bool
                }
            )
    , preIndexed : PreIndexed
    , saveLessonToPdfProgress : Maybe { done : Int, total : Int }
    , kanjidicSearchInput : Maybe String
    , customKanjiLessonTitleInput : Maybe String
    , kanjiEditorNewCoreMeaningLang : Maybe String
    , kanjiEditorNewMeaningLang : Maybe String
    , editingKanji : Maybe KanjidicEntry
    , updatingKanjiStatus : Status

    -- KanjiCanvas
    , kanjiCanvasLoaded : Bool
    , kanjiCanvasOpen : Bool
    , recognizedKanji : List String
    , lastSelectionBounds : Maybe { start : Int, stop : Int }

    -- Grammar
    , currentMaxLess : Int
    , grammarLessons : Dict Int Article

    -- Blog
    , blogEntries : Dict String (Maybe Article)
    , privateBlogEntries : Dict String (Maybe Article)
    , membersBlogEntries : Dict String (Maybe Article)

    -- Presentations
    , presentationRunning : Bool
    , presentationInitalState : Maybe Presentation
    , presentations : Dict String (Maybe Presentation)

    -- Legacy Kana
    , legacyKanaModel : LegacyKana.Model

    -- Pdf reader
    , pdfs : Dict String ( PdfConfig, Bool )
    , pdfReaderPanelOpen : Bool
    , mp3PlayerVisible : Bool
    , pdfIndexVisible : Bool

    -- White board
    , boardOpen : Bool
    , sideBySide : Bool
    , mainContentFullScreen : Bool
    , boardInput : Maybe String
    , realTimeTokenization : Bool
    , boardCurrentInputWithFurigana : Maybe String
    , boardContent : List String
    , currentlyEditing : Maybe Int
    , currentlyLoadingFurigana : Maybe Int
    , autoFurigana : Bool
    , whiteBoardFontSize : Int
    , removeRomajiInWhiteBoard : Bool
    , boardDetached : Bool
    , boardInputPosition : ( Int, Int )
    , boardCurrentInputFontSize : Int
    , boardCurrentInputSize : Int
    , boardLoadingTranslation : Status

    -- Decomposer
    , decomposerInput : Maybe String
    , decomposerTranslatedInput : Maybe String
    , decomposerRichInput : Maybe String
    , decomposerKanaInput : Maybe String
    , decomposerRomajiInput : Maybe String
    , decomposerKanji : List String
    , decomposerLoading : Status
    , decomposerTranslationLoading : Status

    -- Voc Memo
    , vocMemoOpen : Bool
    , vocMemoState : VocMemoState
    , vocMemoVocList :
        List
            { expression : String
            , meaning : String
            , reading : String
            , example : Maybe String
            }
    , vocMemoTitleInput : Maybe String
    , vocMemoExpressionInput : Maybe String
    , vocMemoReadingInput : Maybe String
    , vocMemoMeaningInput : Maybe String
    , vocMemoExampleInput : Maybe String
    , vocMemoLoadingFurigana : Status
    , vocMemoLoadingTranslation : Status
    , vocMemoPosition : ( Int, Int )

    -- mp3 Player
    , currentTrack : Maybe AudioMeta
    , currentPlayList : List AudioMeta
    , trackSelectorOpen : Bool
    , mp3PlaybackSpeed : Float

    -- flashcards
    , decks : Dict Int Deck
    , currentDueCards : Maybe DueCards
    , nextCardId : Int
    , nextDeckId : Int
    , deckNameInput : Maybe String
    , editedCardBuffer : Maybe SRCard
    , flashCardPluginSaving : Status
    , flashCardPluginInitialLoadingDone : Bool
    , reversedDecksSelected : Set.Set Int
    , decksToBeLoadedForGeneralReview : Set.Set Int
    , editingNewCard : Bool

    -- showing whole deck keeps skipped cards in currentDueCards
    -- only True when editing deck content (wholeDeckView)
    , showingWholeDeck : Bool
    , showingAnswer : Bool
    , audioAvailable : Bool
    , newCardsFront : Bool

    -- Verbs quiz
    , verbsQuiz : VerbsQuiz

    -- Verbs table
    , verbsTableConfig : VerbsTableConfig

    -- Adjectives quiz
    , adjectivesQuiz : AdjectiveQuiz

    -- Classical quizes
    , inflectedFormQuiz : InflectedFormQuiz

    -- QCM
    , qcmBank : Dict String QCM

    -- Kanji quizzes
    , kanjiReadingQuizzes : Dict ( Int, String ) YomuRenshu
    , kanjiWritingQuizzes : Dict ( Int, String ) KakuRenshu
    , kanjiQuizFontSize : Int
    , kanjiQuizRevealEverything : Bool

    -- RichJapText
    , richJapTexts : Dict String RJTModel
    }


type VocMemoState
    = VocMemoExprInput
    | VocMemoEditReading
    | VocMemoMeanInput
    | VocMemoDeckNameInput
    | VocMemoExampleInput



--| VocMemoSaving


type MarkdownEditorTarget
    = EditMnnGrammar Int
    | EditBlog String
    | EditMembersBlog String
    | EditPrivateBlog String


type BlogType
    = RegularBlog
    | PrivateBlog
    | MembersBlog


type alias PdfConfig =
    { src : String
    , pdfName : String
    , page : Int
    , pageCount : Int
    , index : PdfIndex
    , audio : List AudioMeta
    , error : Maybe String
    , zoom : Float
    , zoomText : String
    }


type PdfIndex
    = TreeIndex IndexEntry (List PdfIndex)
    | FlatIndex (List ( String, Int ))


type alias IndexEntry =
    { id : Int
    , label : String
    , folded : Bool
    , page : Int
    }


type StorablePdfTreeIndex
    = StTreeIndex StIndexEntry (List StorablePdfTreeIndex)
    | StFlatIndex (List ( String, Int ))


type alias StIndexEntry =
    { label : String
    , page : Int
    }


type alias AudioMeta =
    { audioSrc : String
    , audioLabel : String
    , audioOffset : List Duration
    }


type Msg
    = -- Misc
      UrlClicked UrlRequest
    | UrlChanged Url
    | AppContainerScrolled Viewport
    | Resized Int Int
    | DoOnNextFrame
    | ShiftDown
    | ShiftUp
    | KeyboardMsg Keyboard.Msg
    | AddLog Log
    | AuthPluginMsg AuthMsg
    | GotTime Posix
    | GotMousePos Float Float
    | TogglePrintMode
    | ToggleShowingRomaji
    | SavePdfSimple String
    | TokenizeJapStrings ( List String, ReadingsDict -> Model -> ( Model, Cmd Msg ) )
    | GotJapStringTokens (ReadingsDict -> Model -> ( Model, Cmd Msg )) (Result Http.Error ReadingsDict)
    | LocalhostTokenizationResult (Result Http.Error ReadingsDict)
    | NoOp
      -- MarkdownEditor
    | ToggleEditMarkdown MarkdownEditorTarget
    | MarkdownEditorInput String
    | SaveMarkdown MarkdownEditorTarget String String
    | MarkdownSaved MarkdownEditorTarget (Result Http.Error String)
      -- Vocabulary
    | GetVocabulary
    | GotVocabulary Int (Result Http.Error String)
    | LoadAndPlayAudio String String
    | SoundLoaded Bool String (Result Audio.LoadError Audio.Source)
    | PressedPlay String
    | PressedPlayAndGotTime String Time.Posix
    | ToggleHideJapanese
    | ToggleHideFrench
    | ToggleHideJapaneseWord Int
    | ToggleHideFrenchWord Int
    | ToggleHidePitchAccents
    | EditWordEntry Int
    | VocExprInput String
    | VocReadingInput String
    | VocMeaningInput String
    | PitchAccentInput String
    | UpdateWordEntry
    | WordEntryUpdated (Result Http.Error String)
    | GetKanjisDataForVocabulary WordEntry
    | GotKanjisDataForVocabulary (Result Http.Error (List KanjidicEntry))
      -- Grammar dict
    | GotGrammarDictIndex (Result Http.Error String)
    | SearchGrammarDict String
      -- JMDict
    | GotKebIndex (Result Http.Error String)
    | StartLoadingJMdictXmlIntoMysql
    | GotJMdictXml (Result Http.Error String)
    | JMdictEntryUpdated Int (Result Http.Error String)
    | JMdictEntriesUpdated (List Int) (Result Http.Error (List Int))
    | FromJapSearchInput String
    | FromJapSearch
    | ToJapSearchInput String
    | ToJapSearch
    | GotJMdictSearchResults (Result Http.Error (List JapDictEntry))
    | GetTatoebaExamples Int String
    | GotTatoebaExamples Int (Result Http.Error (List TatoebaExample))
    | SetSearchResultsLanguage JMdictLanguage
    | SetSearchLanguage JMdictLanguage
    | JMdictConvertRomajiInput String
      -- Kanji
    | GotKanjidicXml (Result Http.Error String)
    | GotKodanshaKanji { fr : String, en : String }
    | GotKanjiDecompositions (Result Http.Error String)
    | GotKanjidicKeys (Result Http.Error (List String))
    | GotKanjidicEntry (Result Http.Error KanjidicEntry)
    | GotKanjidicEntries (Result Http.Error (List KanjidicEntry))
    | GifLoaded String
    | LoadLibgif String
    | LibGifLoaded String Int Int
    | PlayPauseGif String
    | ResetGif String
    | PlayGifFrame String Float
    | SetKanjiDisplay String KanjiDisplay
    | SetKanjiMeaningLang String String
    | UpdateKanji (List KanjidicEntry)
    | SaveLessonToPdf String
    | SaveLessonToPdfProgress (Result D.Error { done : Int, total : Int })
    | KanjidicSearchInput Bool String
    | CustomKanjiLessonTitleInput String
    | SearchKanjidic
      -- KanjiEditor
    | EditKanji KanjidicEntry
    | EditCoreMeanings Int String
    | EditMeanings Int String
    | AddKanjiNewCoreMeaning String
    | AddKanjiNewMeaning String
    | RemoveKanjiCoreMeaning Int
    | RemoveKanjiMeaning Int
    | SwapKanjiCoreMeaning Int Bool
    | SwapKanjiMeaning Int Bool
    | SetEditedKanjiCoreMeaningLang String
    | SetEditedKanjiMeaningLang String
    | UpdateEditedKanji KanjidicEntry
    | KanjiUpdated KanjidicEntry (Result Http.Error String)
      -- KanjiCanvas
    | GetLastSelectionBounds String
    | GotLastSelectionBounds D.Value
    | ToggleKanjiCanvas
    | InitializeKanjiCanvas
    | EraseKanjiCanvas
    | DeleteLastKanjiCanvas
    | RecognizeKanjiCanvas
    | ProcessMessagefromKanjiCanvas D.Value
      -- Grammar
    | GetMnnGrammar Int
    | GotMnnGrammar Int (Result Http.Error String)
      -- Blog
    | GotBlogEntry String (Result Http.Error String)
    | GotPrivateBlogIndex (Result Http.Error (List String))
    | GotMembersBlogEntry String (Result Http.Error String)
    | GotPrivateBlogEntry String (Result Http.Error String)
      -- Presentations
    | GotPresentation String (Result Http.Error String)
    | OpenSlide Int
    | AdvancePresentation
    | ResetPresentation
      -- LegacyKana
    | LegacyKanaMsg LegacyKana.Msg
      -- Pdf reader
    | OpenClick
    | PdfOpened File
    | PdfExtracted String String
    | GotPdfConfigs (Result Http.Error (List PdfConfig))
    | PdfMsg (Result D.Error PdfElement.PdfMsg)
    | PrevPage String
    | NextPage String
    | GoToPage String Int
    | ZoomChanged String String
    | OkError String
    | TogglePdfReaderPanel
    | ToggleMp3PlayerVisible
    | TogglePdfIndexVisible
    | TogglePdfIndexEntry String Int
      -- White board
    | ToggleBoard
    | ToggleMouseTracking
    | ToggleSideBySide
    | ToggleMainContentFullScreen
    | WhiteBoardInput String
    | AddBracketsToBoard
    | AddToBoard
    | ClearBoard
    | RemoveFromBoard Int
    | EditBoardItem Int
    | SwapBoardItemUp Int
    | SwapBoardItemDown Int
    | ToggleAutoFurigana
    | GetFurigana Int String
    | CurrentBoardTokenizationResult (List String) (Result Http.Error String)
    | IncreaseWhiteBoardFontSize
    | DecreaseWhiteBoardFontSize
    | ToggleRomajiInWhiteBoard
    | ChangeCurrentBoardSize Int
    | ChangeCurrentBoardFontSize Int
    | RequestWhiteboardTranslation
    | WhiteboardTranslationInput (Result Http.Error String)
      -- Decomposer
    | DecomposerInput String
    | DecomposerGetFurigana String
    | DecomposerTranslate String
    | DecomposerGotTranslation (Result Http.Error String)
      --VocMemo
    | VocMemoAddCustomString String
    | ResetVocMemo
    | ToggleVocMemo
    | VocMemoExpressionInput String
    | VocMemoValidateExpressionInput
    | VocMemoReadingInput String
    | VocMemoMeaningInput String
    | VocMemoTranslationInput (Result Http.Error String)
    | VocMemoExamInput String
    | AddWordToVocMemo
    | VocMemoDeckTitleInput String
    | VocMemoSaveDeck
    | VocMemoMakeAnkiDeck
    | SetVocMemoStateTo VocMemoState
    | OnDragBy Vec2
    | DragMsg (Draggable.Msg String)
    | StartDragging String
      -- Mp3 Player
    | Mp3PlayerPressedPlayPause String
    | Mp3PlayerPressedPlayPauseAndGotTime String Time.Posix
    | Mp3PlayerSelectTrack String
    | Mp3PlayerSkipToNextTrack
    | Mp3PlayerSkipToPrevTrack
    | Mp3PlayerSkipTo Duration
    | Mp3PlayerSkipToNextBookmark
    | Mp3PlayerSkipToPrevBookmark
    | Mp3PlayerToggleTrackSelector
      -- FlashCards
    | CreateMnnDeck Int
    | CreateKanjiLessonDeck String (List String)
    | CreateKanjiVocabDeck String (Either ( ( Lesson, Int ), ( Lesson, Int ) ) ( Lesson, Int )) String
    | CreateReverseDeck Int
    | CreateNewCustomDeck
    | ConfirmDeckCreation Deck (Result Http.Error String)
    | GotDecksAndNextIds
        String
        (Result
            Http.Error
            { decks : List Deck
            , nextCardId : Int
            , nextDeckId : Int
            }
        )
    | GotDeckCards String Int (Result Http.Error (List SRCard))
    | LoadDueCards Int Posix
    | LoadDueCardsFromAllDecks Posix
    | ResetDeck Int
    | SetShowingPolicy Int ShowingPolicy
    | SetFuriganaPolicy Int FuriganaPolicy
    | ConfirmDeckUpdate Int Deck (Result Http.Error String)
    | DeleteDeck Int
    | ConfirmDeckDeletion Int (Result Http.Error String)
    | DeleteCard Int Int
    | ConfirmCardDeletion Int Int (Result Http.Error String)
    | ToggleSkip Int Int
    | SkipCard
    | ToggleReversed Int Int
    | ToggleShowFurigana Int Int
    | ToggleAudioAvailable
    | SetNewCardsFront Bool
    | ShowAnswer
    | RequestTimeAndAnswer SR.Answer
    | AnswerCard SR.Answer Posix
    | ConfirmAnsweredCardUpdate Deck DueCards (Result Http.Error String)
    | ConfirmCardUpdate Deck (Result Http.Error String)
    | ToggleReversedDeck Int
    | DeckNameInput String
    | SaveDeckName Int
    | SelectCard Int Int
    | CreateNewCard Int
    | CardExpressionInput String
    | CardMeaningInput String
    | CardReadingInput String
    | CardExampleInput String
    | SaveEditedCard Int
      -- Verbs Table
    | ToggleVerbsTableOption VerbsTableConfigOpts
      -- Verbs Quiz
    | VerbsQuiz QuizMsg
      -- Adjectives Quiz
    | AdjectivesQuiz AdjQuizMsg
      -- Classical Quizes
    | InflectedFormQuiz IFQuizMsg
      -- QCM
    | AnswerQCM String Int String
    | SetQCMRandomState String Bool
      -- Kanji quizzes
    | CheckKanjiReadingQuizAnswer ( Int, String ) Int Int
    | CheckKanjiWritingQuizAnswer ( Int, String ) Int Int
    | ChangeKanjiQuizFontSize Int
    | ToggleKanjiQuizRevealEveryThing
      -- RichJapText
    | RichJapTextMsg String RJTMsg


type Route
    = Home
    | Kana String
    | GrammarDict String
    | Kanjidic KanjiRoute
    | JMDict JMDictRoute
    | MinnaNoNihongo MinnaNoNihongoRoute
    | Blog String
    | MembersBlogRoute String
    | PrivateBlogRoute String
    | Presentations String
    | AuthPlugin
    | LegalInfo
    | JapaneseClassInfo
    | ReferencesInfo
    | FlashCards FlashCardsRoute
    | Verbs VerbsRoute
    | Classical ClassicalRoute
    | Adjectives AdjectivesRoute
    | CustomPdf String
    | Decomposer
    | RecapBaseFormsRoute


type MinnaNoNihongoRoute
    = MnnVocabulary Int
    | MnnKanjiLesson String String (List String)
    | MnnGrammarLesson Int
    | MnnManual String


type KanjiRoute
    = KanjidicIndex
    | Kanji String
    | KanjiLesson (List String)
    | KanjiNotes String
    | KanjiQuiz ( Int, String )


type JMDictRoute
    = JMDictIndex
    | JMDictFromJapSearch String
    | JMDictToJapSearch String


type FlashCardsRoute
    = FlashCardsHome
    | FlashCardsDeckHome Int
    | FlashCardsStudy Int Int
    | FlashCardStudyAllDues
    | FlashCardSeeAllDues


type SoundState
    = NotPlaying
    | Playing String Time.Posix
    | PlayingStartedAt String Time.Posix Duration
    | Paused String Duration


type VerbsRoute
    = VerbsIndex
    | VerbsQuizRoute
    | Transitivity


type ClassicalRoute
    = ClassicalIndex
    | ClassicalInflectedFormQuiz


type AdjectivesRoute
    = AdjectivesIndex



--| FadingOut String Time.Posix Time.Posix
-------------------------------------------------------------------------------


type alias Article =
    { articleStyle : List StyleAttribute
    , markdown : String
    }


type StyleAttribute
    = Font String
    | FontSize Int
    | Color String
    | BackgroundColor String
    | Align Alignment
    | Justify Bool


type Alignment
    = AlignLeft
    | AlignRight
    | CenterAlign


type alias Presentation =
    { name : String
    , toPlay : List SlideElement
    , played : List SlideElement
    }


type SlideElement
    = SlideCol Bool (List SlideElement)
    | SlideRow Bool (List SlideElement)
    | SlideContent Bool (List ( Bool, Article ))



-------------------------------------------------------------------------------
-- Grammar dict


type alias GrammarDictEntry =
    { entry : String
    , entryJapanese : Maybe String
    , foundUnder : Maybe String
    , englishMeaning : Maybe String
    , index : GrammarDictIndex
    }


type GrammarDictIndex
    = Basic Int
    | Intermediate Int
    | Advanced Int
    | Multiple (List GrammarDictIndex)



-------------------------------------------------------------------------------
-- Pitch Accent


type PitchAccent
    = Heiban
    | AtamaDaka
    | NakaDaka Int
    | ODaka


type Accent
    = Low
    | High
    | DownStep



-------------------------------------------------------------------------------
-- Vocabulary


type alias Lesson =
    List WordEntry


type alias WordEntry =
    { expression : String
    , meaning : String
    , reading : List Writing
    , lessNumber : Int
    , expressionHidden : Bool
    , meaningHidden : Bool
    , pitchAccents : List ( String, Bool, PitchAccent )
    }


type alias Reading =
    List JapaneseString


type JapaneseString
    = Plain String
    | WithFurigana String Furigana


type alias Furigana =
    String


type alias CompleteJapString =
    { jap : List JapaneseString
    , romaji : String
    }


type Writing
    = Latin String
    | JpStr CompleteJapString



-------------------------------------------------------------------------------
-- JMDict


type alias JapDictEntry =
    { ent_seq : Int
    , k_ele : List KanjiElement
    , r_ele : List ReadingElement
    , sense : List Sense
    , showingEverySense : Bool
    }


type alias KanjiElement =
    { keb : String
    , k_inf : List String
    , k_pri : List String
    }


type alias ReadingElement =
    { reb : String
    , re_nokanji : Bool
    , re_restr : List String
    , re_inf : List String
    , re_pri : List String
    }


type alias Sense =
    { stagk : List String
    , stagr : List String
    , pos : List String
    , xref : List String
    , ant : List String
    , field : List String
    , misc : List String
    , s_inf : List String
    , lsource : List LSource
    , dial : List String
    , gloss : List Gloss
    , example : List Example
    }


type LSource
    = LSource
        String
        { xmlLang : Maybe String -- def eng
        , ls_type : Maybe String
        , ls_wasei : Bool
        }


type Gloss
    = Gloss
        String
        { xmlLang : Maybe String -- def eng
        , g_gend : Maybe String
        , g_type : Maybe String
        }


type alias Example =
    { ex_srce : String
    , ex_text : String
    , ex_sent : List Ex_sent
    }


type Ex_sent
    = Ex_sent
        String
        { xmlLang : Maybe String
        , ex_srce : Maybe String
        }


type JMdictLanguage
    = SearchInFrench
    | SearchInEnglish
    | SearchEverything


type alias JMdictFromJapSearch =
    { searchStr : String
    , hasKanji : Bool
    , targetLanguage : JMdictLanguage
    }


type alias JMdictToJapSearch =
    { searchStr : String
    , targetLanguage : JMdictLanguage
    }


type alias TatoebaExample =
    { text : String
    , translations : List TatoebaTranslation
    , transcriptions : List TatoebaTranscription
    }


type alias TatoebaTranslation =
    ( String, String )


type alias TatoebaTranscription =
    String



-------------------------------------------------------------------------------
-- Kanji


type alias KanjidicEntry =
    { kanji : String
    , cpValues : List ( String, String )
    , radValues : List ( String, Int )

    -- misc
    , grade : Maybe Int
    , strokeCount : List Int
    , variants : List ( ( String, String ), Maybe String )
    , freq : Maybe Int
    , radName : List String
    , jlpt : Maybe Int

    --
    , dicNumber : List ( String, String )
    , queryCode : List ( String, String )
    , skipMissclass : List ( String, String )

    -- reading/meaning
    , readings : List { rType : String, onType : Maybe String, rStatus : Maybe String, reading : String }
    , meanings : List ( String, String )
    , nanori : List String

    -- custom fields
    , coreMeanings : List ( String, String )
    , examples : List ( String, String )
    , decomposition : Maybe String
    , etymology : Maybe { hint : Maybe String, etym : Maybe String }

    -- Jitenon
    , jitenon : Maybe JitenonKanji2
    }


type KanjiDisplay
    = RegularKanji
    | StrokeOrderFont
    | AnimatedKanji


type alias PreIndexed =
    { firstYear : List String
    , secondYear : List String
    , thirdYear : List String
    , fourthYear : List String
    , fifthYear : List String
    , sixthYear : List String
    , frequencySorted : List String
    , jlpt1 : List String
    , jlpt2 : List String
    , jlpt3 : List String
    , jlpt4 : List String
    }


type alias JitenonKanji =
    { unicode : String
    , kanji : String
    , buShu : String
    , kakuSuu : Int
    , subeteNoYomiKuBunAri : String
    , onYoMiKuBunAri : String
    , kunYomiKuBunAri : String
    , imiKuBunAri : String
    , subeteNoYomiKuBunNashi : String
    , onYoMiKuBunNashi : String
    , kunYomiKuBunNashi : String
    , imiKuBunNashi : String
    , nanDoku : String
    , nanori : String
    , shuBetsu : String
    , iTaiJi : String
    , jitenonNumber : Int
    }


type alias JitenonKanji2 =
    { kanji : String
    , kakuSuu : String
    , buShu : String
    , kankenKyuu : Maybe String
    , gakuNen : Maybe String
    , onYomi : List String
    , kunYomi : List String
    , imi : List String
    , nariTachi : Maybe String
    , shuBetsu : List String
    , unicode : String
    , jitenonNumber : Int
    , nanDoku : List String
    }



-------------------------------------------------------------------------------
-- FlashCards


type ContentReference
    = MnnVocCardContentRef
        { lesson : Int
        , expression : String
        }
    | KanjiCardContentRef String
      --| KanjiVocContentRef
      --    { expression : String
      --    , reading : String
      --    , relevantKanji : String
      --    }
    | CustomContentRef
        { expression : String
        , meaning : String
        , reading : String
        , example : Maybe String
        }


type alias SRCard =
    SR.Card
        { id : Int
        , owner : String
        , contentReference : ContentReference
        , skipped : Bool
        , reversed : Bool
        , showFurigana : Bool
        }


type alias Deck =
    SR.Deck
        { id : Int
        , name : String
        , owner : String
        , showingPolicy : ShowingPolicy
        , furiganaPolicy : FuriganaPolicy
        }
        SRCard


type ShowingPolicy
    = ShowingFront
    | ShowingBack
    | ShowingCustom
    | ShowingRandom


type FuriganaPolicy
    = ShowFurigana
    | HideFurigana
    | CustomShowFurigana
    | ShowFuriganaExceptFor String


type alias DueCards =
    --( Int
    --,
    List
        { deckId : Int
        , index : Int
        , queueDetails : SR.QueueDetails
        , isLeech : Bool
        }



--)


type alias QueueStats =
    { newCard : Int
    , learning : Int
    , review : Int
    , lapsed : Int
    }



--type alias FCModel a =
--    { a
--        |
--    }
-------------------------------------------------------------------------------
-- Logger


type alias Log =
    { message : String
    , mbDetails : Maybe String
    , isError : Bool
    , isImportant : Bool
    , timeStamp : Posix
    }



-------------------------------------------------------------------------------
-- JapPreprocessor


type alias ReadingsDict =
    Dict String ReadingObject


type alias ReadingObject =
    List JapaneseStringObject


type alias JapaneseStringObject =
    { kana : String
    , lemma : String
    , pos1 : String
    , pos2 : String
    , pos3 : String
    , pos4 : String
    , surface : String
    }



-------------------------------------------------------------------------------
-- Verbs quiz


type alias Verb =
    { dict : String
    , kana : String
    , romaji : String
    , meaning : String
    , group : Int
    }


type alias QuizConfig =
    { promptType : Nonempty VerbForm
    , answerType : Nonempty VerbForm
    , quizzedGroups : Set.Set Int
    , quizDisplay : QuizDisplay
    , nbrPrompts : Int
    , seed : Random.Seed
    }


type QuizDisplay
    = DisplayOnlyRomaji
    | DisplayWithFurigana
    | DisplayKanji
    | DisplayOnlyHiragana


type QuizMode
    = RandomQuiz
    | AdaptativeQuiz


type VerbForm
    = PlainForm
    | MasuForm
    | TeForm
    | TaForm
    | NaiForm
    | NaiPastForm
    | Volitional
    | Potential
    | Hypothetical
    | Passive
    | Causative
    | Imperative
      -- Extra forms
    | PermissionForm
    | InterdictionForm
    | NoNeedForm
    | PoliteRequestForm
    | PoliteNegativeRequestForm
    | AdviceForm
    | NegAdviceForm
    | Obligation1Form
    | Obligation2Form
    | DesireForm
    | NegDesireForm
    | PastDesireForm
    | NegPastDesireForm


type VerbsQuiz
    = LoadingQuiz
        (State
            { prompting : Allowed }
            { config : QuizConfig
            , nbrPromptsInput : Maybe String
            }
        )
    | Prompting
        (State
            { initial : Allowed
            , showingAnswer : Allowed
            }
            { config : QuizConfig
            , showingHint : Bool
            , hints : VQLesson
            , inputStr : Maybe String
            , processedInput : Maybe String
            , currentPrompt : CurrentPrompt
            , score : Int
            , deck : List Verb
            , wrongAnswers : List ( CurrentPrompt, String )
            }
        )
    | ShowingAnswer
        (State
            { initial : Allowed
            , prompting : Allowed
            , result : Allowed
            }
            { config : QuizConfig
            , currentPrompt : CurrentPrompt
            , answered : String
            , score : Int
            , deck : List Verb
            , wrongAnswers : List ( CurrentPrompt, String )
            }
        )
    | Result
        (State
            { initial : Allowed }
            { score : Int
            , config : QuizConfig
            , wrongAnswers : List ( CurrentPrompt, String )
            }
        )
    | Error
        (State
            { initial : Allowed }
            { message : String }
        )


type alias CurrentPrompt =
    { prompt : ( VerbForm, String )
    , answer : ( VerbForm, String )
    , verb : Verb
    }


type QuizMsg
    = StartQuiz
    | SetPromptType VerbForm
    | SetAnswerType VerbForm
    | SetNbrPrompts String
    | SetQuizzedGroups Int
    | Answer String
    | CheckAnswer
    | ContinueOrFinish
    | SetQuizDisplay QuizDisplay
    | ToggleShowHints
    | HintsNextPage
    | HintPrevPage
    | ResetQuiz
    | QuizNoOp


type alias VQLesson =
    RL.RollingList LessonPage


type alias LessonPage =
    { title : String
    , content : Element QuizMsg
    }



-------------------------------------------------------------------------------
--type alias VerbsTableConfig =
--    { displayFrenchMeaning : Bool
--    , displayDictForm : Bool
--    , displayMasuForm : Bool
--    , displayNaiForm : Bool
--    , displayTeForm : Bool
--    , displayTaForm : Bool
--    , displayVolitive : Bool
--    , displayImperative : Bool
--    , displayConditionnal : Bool
--    , displayPotential : Bool
--    , displayPassive : Bool
--    , displayFactitive : Bool
--    , headerInFrench : Bool
--    , width : Int
--    }


type alias VerbsTableConfig =
    { options : List VerbsTableConfigOpts
    , width : Int
    }


type VerbsTableConfigOpts
    = VTFrench
    | VTDictForm
    | VTMasuForm
    | VTNaiForm
    | VTTeForm
    | VTTaForm
    | VTVolitve
    | VTImperative
    | VTConditional
    | VTPotential
    | VTPassive
    | VTFactitive
    | VTHeaderInFrench
    | VTShowRomaji



-------------------------------------------------------------------------------
-- Adectives quiz


type KeiYouShi
    = --　形容詞
      IKeiYouShi
        { reading : CompleteJapString
        , meanings : List String
        }
      --　形容動詞
    | NaKeiYouShi
        { reading : CompleteJapString
        , meanings : List String
        }


type AdjectiveForm
    = AdjFinalForm
    | AdjNegForm
    | AdjPastForm
    | AdjNegPastForm
    | AdjPrenominal
    | AdjAdverbial
    | AdjTeForm
    | AdjEvenIfForm
    | AdjEvenIfNotForm
    | AdjRaConditional
    | AdjBaNaraConditional


type alias AdjQuizConfig =
    { promptType : Nonempty AdjectiveForm
    , answerType : Nonempty AdjectiveForm
    , quizDisplay : QuizDisplay
    , nbrPrompts : Int
    , seed : Random.Seed
    , iKeiYouShiQuizzed : Bool
    , naKeiYouShiQuizzed : Bool
    , politeStyle : Bool
    }


type AdjectiveQuiz
    = AdjLoadingQuiz
        (State
            { prompting : Allowed }
            { config : AdjQuizConfig
            , nbrPromptsInput : Maybe String
            }
        )
    | AdjPrompting
        (State
            { initial : Allowed
            , showingAnswer : Allowed
            }
            { config : AdjQuizConfig

            --, hints : VQLesson
            , inputStr : Maybe String
            , processedInput : Maybe String
            , currentPrompt : AdjCurrentPrompt
            , score : Int
            , deck : List KeiYouShi
            }
        )
    | AdjShowingAnswer
        (State
            { initial : Allowed
            , prompting : Allowed
            , result : Allowed
            }
            { config : AdjQuizConfig
            , currentPrompt : AdjCurrentPrompt
            , answered : String
            , score : Int
            , deck : List KeiYouShi
            }
        )
    | AdjResult
        (State
            { initial : Allowed }
            { score : Int
            , config : AdjQuizConfig
            }
        )
    | AdjError
        (State
            { initial : Allowed }
            { message : String }
        )


type alias AdjCurrentPrompt =
    { prompt : ( AdjectiveForm, String )
    , answer : ( AdjectiveForm, String )
    , adjective : KeiYouShi
    }


type AdjQuizMsg
    = AdjStartQuiz
    | AdjSetPromptType AdjectiveForm
    | AdjSetAnswerType AdjectiveForm
    | AdjSetNbrPrompts String
    | AdjToggleIKeyYouShiQuizzed Bool
    | AdjToggleNaKeyYouShiQuizzed Bool
    | AdjTogglePoliteStyle Bool
    | AdjAnswer String
    | AdjCheckAnswer
    | AdjContinueOrFinish
    | AdjSetQuizDisplay QuizDisplay
      --| ToggleShowHints
      --| HintsNextPage
      --| HintPrevPage
    | AdjResetQuiz
    | AdjQuizNoOp



-------------------------------------------------------------------------------
-- InflectedForm quiz


type InflectedForm
    = ClassicalVerb CV
    | ClassicalAuxiliary Auxiliary
    | ClassicalAdjective CA
    | ClassicalCopula Copula


type Form
    = Mizenkei
    | Renyoukei
    | Shushikei
    | Rentaikei
    | Izenkei
    | MeireiKei


type ConjugationType
    = YoDan
    | KamiIchiDan
    | ShimoIchiDan
    | KamiNiDan
    | ShimoNiDan
    | KaHen
    | SaHen
    | RaHen
    | NaHen


type Adjective
    = KuKeiYouShi
    | ShikuKeiYouShi
    | NariKeiYouDouShi
    | TariKeiYouDouShi


type alias CA =
    { ss : String
    , kana : String
    , ct : Adjective
    , meaning : String
    }


type Copula
    = Nari_cop
    | Tari_cop


type Transitivity
    = Transitive
    | Intransitive
    | AmbiTransitive


type alias CV =
    { ss : String
    , kana : String
    , row : String
    , ct : ConjugationType
    , transitivity : Transitivity
    , meaning : String
    }


type Auxiliary
    = -- Spontaneous, potential, passive, honorific
      Ru
    | Raru
      -- Causative, honorific
    | Su
    | Sasu
    | Shimu
      -- Perfective, certainty, parallel
    | Tsu
    | Nu
      -- Resultative, continuative, perfective
    | Tari
    | Ri
      -- Personal past
    | Ki
      -- Past hearsay, exclamatory, recognition, direct past
    | Keri
      -- Speculation, intention, appropriateness, urging, circumlocution, hypothetical
    | Mu
      -- Intention, speculation
    | Muzu
      -- Present speculation
    | Ramu
      -- Past speculation
    | Kemu
      -- Visual supposition, circumocution
    | Meri
      -- Conjucture with confidence, strong intention, appropriateness, advice, command, potential
    | Beshi
      -- Evidential suposition
    | Rashi
      --　Counterfactual speculation, desire for hypothetical state, hesitation
    | Mashi
      -- Hearsay, aural supposition, direct hearing
    | Nari
      -- Negation
    | Zu
      -- Negative speculation, negative intention
    | Ji
      -- Negative speculation, negative intention, inapropriateness, negative potential, prohibition
    | Maji
      -- First person desire, third person desire, situational desire
    | Mahoshi
    | Tashi
      -- Comparison, example
    | Gotoshi


type alias IFQuizConfig =
    { promptType : NE.Nonempty Form
    , answerType : NE.Nonempty Form
    , quizFilter :
        { quizAuxiliaries : Bool
        , quizVerbs : List ConjugationType
        , quizAdjectives : Bool
        , quizCopulas : Bool
        }
    , nbrPrompts : Int
    , seed : Random.Seed
    }


type InflectedFormQuiz
    = IFLoadingQuiz
        (State
            { prompting : Allowed }
            { config : IFQuizConfig
            , nbrPromptsInput : Maybe String
            }
        )
    | IFPrompting
        (State
            { initial : Allowed
            , showingAnswer : Allowed
            }
            { config : IFQuizConfig
            , showingHint : Bool
            , hints : VQLesson
            , inputStr : Maybe String
            , processedInput : Maybe String
            , currentPrompt : IFCurrentPrompt
            , score : Int
            , deck : List InflectedForm
            }
        )
    | IFShowingAnswer
        (State
            { initial : Allowed
            , prompting : Allowed
            , result : Allowed
            }
            { config : IFQuizConfig
            , currentPrompt : IFCurrentPrompt
            , answered : String
            , score : Int
            , deck : List InflectedForm
            }
        )
    | IFResult
        (State
            { initial : Allowed }
            { score : Int
            , config : IFQuizConfig
            }
        )
    | IFError
        (State
            { initial : Allowed }
            { message : String }
        )


type alias IFCurrentPrompt =
    { prompt : ( Form, List String )
    , answer : ( Form, List String )
    , inflectedForm : InflectedForm
    }


type IFQuizMsg
    = IFStartQuiz
    | IFSetPromptType Form
    | IFSetAnswerType Form
    | IFSetNbrPrompts String
    | IFSetQuizAuxiliaries Bool
    | IFSetQuizAdjectives Bool
    | IFSetQuizCopulas Bool
    | IFSetQuizConjugationType ConjugationType
    | IFAnswer String
    | IFCheckAnswer
    | IFContinueOrFinish
    | IFToggleShowHints
    | IFHintsNextPage
    | IFHintPrevPage
    | IFResetQuiz
    | IFQuizNoOp



-------------------------------------------------------------------------------
-- QCM


type alias QCM =
    { id : String
    , title : String
    , data : Dict Int QCMPrompt
    , showNotesOnAnswer : Bool
    , randomize : Bool
    }


type alias QCMPrompt =
    { prompt : String
    , choices : List ( String, Maybe String )
    , correctAnswer : String
    , mbChosenAnswer : Maybe String
    , mbNotes : Maybe String
    }



-------------------------------------------------------------------------------
-- Kanji quizzes


type alias YomuRenshu =
    Dict Int ClickableReading


type alias KakuRenshu =
    Dict Int ClickableReading


type alias ClickableReading =
    List ClickableJapaneseString


type ClickableJapaneseString
    = PlainCJS String
    | WithFuriganaCJS
        { raw : String
        , furigana : String
        , index : Int
        , reversedFurigana : Bool
        , rubyShown : Bool
        }



-------------------------------------------------------------------------------
-- Auth


type AuthMsg
    = SetUsername String
    | SetPassword String
    | SetConfirmPassword String
    | SetEmail String
      ----------------
    | LoginRequest
    | LoginRequestResult (Result Http.Error LoginResult)
      ----------------
    | SelectUser String
    | SelectCurrentStudent String
    | LoginAsSelectedUser
      ----------------
    | InitiatePasswordResetRequest
    | InitiatePasswordResetRequestResult (Result Http.Error InitiatePasswordResetResult)
    | UpdatePasswordRequest
    | UpdatePasswordRequestResult (Result Http.Error UpdatePasswordResult)
      ----------------
    | SetVerificationCode String
    | CodeVerificationRequest
    | CodeVerificationRequestResult (Result Http.Error CodeVerificationResult)
    | CodeVerificationToogleInternalStatus
    | NewCodeRequest
    | NewCodeResult (Result Http.Error NewCodeResult)
      -----------------
    | SignupRequest
    | SignupRequestResult (Result Http.Error SignupResult)
      -----------------
    | LogoutRequest
    | LogoutRequestResult (Result Http.Error LogoutResult)
      -----------------
    | Refresh
    | RefreshResult (Result Http.Error LoginResult)
      -----------------
    | ToLogin LoginModel Bool
    | ToCodeVerification CodeVerificationModel
    | ToSignup SignupModel
    | ToLogout LogoutModel
    | ToPasswordReset PasswordResetModel
    | AuthNoOp


type Auth
    = Login
        (State
            { signup : Allowed
            , codeVerification : Allowed
            , passwordReset : Allowed
            , userControlPanel : Allowed
            , adminControlPanel : Allowed
            , login : Allowed
            }
            LoginModel
        )
    | PasswordReset
        (State
            { login : Allowed
            , codeVerification : Allowed
            }
            PasswordResetModel
        )
    | CodeVerification
        (D.Value -> AuthMsg)
        (State
            { codeVerification : Allowed
            , login : Allowed
            , passwordReset : Allowed
            , userControlPanel : Allowed
            , adminControlPanel : Allowed
            }
            CodeVerificationModel
        )
    | UserControlPanel
        (State
            { logout : Allowed
            , codeVerification : Allowed
            }
            UserControlPanelModel
        )
    | AdminControlPanel
        (State
            { logout : Allowed
            , codeVerification : Allowed
            , userControlPanel : Allowed
            , adminControlPanel : Allowed
            }
            AdminControlPanelModel
        )
    | Signup
        (State
            { signup : Allowed
            , login : Allowed
            , codeVerification : Allowed
            }
            SignupModel
        )
    | Logout
        (State
            { logout : Allowed
            , login : Allowed
            }
            LogoutModel
        )


type LogInfo
    = LoggedIn UserProfile
    | LoggedOut


type alias LoginModel =
    { username : String
    , password : String
    , requestStatus : Status
    , showValidationErrors : Bool
    , validationErrors : ValidationErrors
    }


type LoginResult
    = LoginSuccess UserProfile
    | LoginWrongCredentials
    | LoginNeedEmailConfirmation
    | LoginTooManyRequests
    | LoginUnknownUsername
    | NotLoggedIn


type alias LogoutModel =
    { requestStatus : Status
    , autoLogout : Bool
    }


type LogoutResult
    = LogoutSuccess
    | LogoutNotLoggedIn


type alias SignupModel =
    { username : String
    , email : String
    , password : String
    , confirmPassword : String
    , requestStatus : Status
    , showValidationErrors : Bool
    , validationErrors : ValidationErrors
    }


type SignupResult
    = SignupSuccess
    | SignupInvalidEmail
    | SignupUserAlreadyExists
    | SignupTooManyRequests
    | SignupInvalidPassword


type alias UserControlPanelModel =
    { newEmail : String
    , password : String
    , confirmPassword : String
    , userProfile : UserProfile
    , showValidationErrors : Bool
    , validationErrors : ValidationErrors
    }


type alias AdminControlPanelModel =
    { newEmail : String
    , password : String
    , confirmPassword : String
    , userProfile : UserProfile
    , showValidationErrors : Bool
    , validationErrors : ValidationErrors
    , users : List String
    , usernameInput : Maybe String
    , currentStudentInput : Maybe String
    }


type alias CodeVerificationModel =
    { code : String
    , email : String
    , askForEmail : Bool
    , canResendCode : Bool
    , verificationNotice : String
    , verificationEndpoint : String
    , showValidationErrors : Bool
    , validationErrors : ValidationErrors
    , internalStatus : CVInternalStatus
    }


type CodeVerificationResult
    = CodeVerificationSuccess D.Value
    | CodeVerificationInvalidCode
    | CodeVerificationInvalidSelectorTokenPairException
    | CodeVerificationTokenExpiredException
    | CodeVerificationUserAlreadyExistsException
    | CodeVerificationTooManyAttempts
    | CodeVerificationGenericError


type NewCodeResult
    = NewCodeSuccess
    | NewCodeTooManyAttemps
    | NewCodeNoPreviousAttempt


type alias PasswordResetModel =
    { email : String
    , password : String
    , confirmPassword : String
    , encryptedSelectorAndToken : D.Value
    , internalStatus : PRInternalStatus
    , showValidationErrors : Bool
    , validationErrors : ValidationErrors
    }


type UpdatePasswordResult
    = UpdatePasswordSuccess
    | UpdatePasswordInvalidSelectorTokenPair
    | UpdatePasswordTokenExpired
    | UpdateInitiatePasswordResetDisabled
    | UpdatePasswordInvalidPassword
    | UpdatePasswordTooManyRequests


type InitiatePasswordResetResult
    = InitiatePasswordResetSuccess
    | InitiatePasswordResetInvalidEmail
    | InitiatePasswordResetEmailNotVerified
    | InitiatePasswordResetResetDisabled
    | InitiatePasswordResetTooManyRequests


type CVInternalStatus
    = VerifyingCode Status
    | RequestingNewCode Status


type PRInternalStatus
    = InitiatingPasswordResetRequest Status
    | UpdatingPasswordRequest Status


type alias FieldId =
    String


type alias ValidationErrors =
    Dict FieldId (List String)


type Role
    = Admin (List String)
    | User


type alias UserProfile =
    { username : String
    , email : String
    , role : Role
    }



-------------------------------------------------------------------------------
--RichJapText


type alias RJTModel =
    { sentences : Dict Int EditableSentence
    , initialInput : Maybe String
    , width : Int
    , height : Int
    , mode : RJTMode
    , previewOn : Bool
    , sourceUrl : String
    , exportName : Maybe String
    , mbId : Maybe String
    }


type alias EditableSentence =
    { japanese : Maybe String
    , romaji : Maybe String
    , french : Maybe String
    , showFrench : Bool
    , display : RJTDisplay
    }


type alias Sentence =
    { japanese : String
    , romaji : String
    , french : String
    , showFrench : Bool
    , display : RJTDisplay
    }


type RJTMsg
    = RJTSetInitialInput String
    | RJTConvertToSentences
    | RJTSetExportName String
    | RJTSetRJTJapanese Int String
    | RJTSetRJTRomaji Int String
    | RJTSetFrench Int String
    | RJTSetDisplay (Maybe Int) RJTDisplay
    | RJTToggleAllFrench
    | RJTToggleFrench Int
    | RJTTogglePreview Bool
    | RJTGotJapStringTokens (ReadingsDict -> RJTModel -> RJTModel) (Result Http.Error ReadingsDict)
    | RJTTranslationRequested
    | RJTDataRequested
    | RJTDataLoaded File
    | RJTImportData String
    | RJTWindowResize Int Int
    | RJTNoOp


type RJTMode
    = RJTAdmin
    | RJTStudent


type RJTDisplay
    = RJTRomaji
    | RJTJapanese RJTJapaneseDisplay


type RJTJapaneseDisplay
    = RJTOnlyKanji
    | RJTOnlyFurigana
    | RJTKanjiWithFurigana



-------------------------------------------------------------------------------
-- Utils


type Status
    = Initial
    | Waiting
    | Success
    | Failure


type PluginResult a
    = PluginQuit
    | PluginData a


type Either a b
    = Left a
    | Right b
