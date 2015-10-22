module OptionsEditor where

import Jenkins
import Debug
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json exposing ((:=))
import Signal exposing (Signal, Address)
import Task
import Effects exposing (Effects, Never)
import StartApp


------------------------------------------------------------------------------
-- Things we're working with here
------------------------------------------------------------------------------
type alias JenkinsConfig = Jenkins.Config

emptyConfig : JenkinsConfig
emptyConfig = { serverURL = "https://jenkins.example/"
              , jobNames = [ "job1", "job2" ]
              , buildOnBranchChange = True
              }

------------------------------------------------------------------------------
-- Things we can do
------------------------------------------------------------------------------

type Action
  = NoOp
  | AddJobName String
  | DeleteJobName String
  | SetBuildOnBranchChange Bool

update : Action -> JenkinsConfig -> (JenkinsConfig, Effects Action)
update action model =
  case action of
    NoOp -> noFx model
    AddJobName name -> noFx { model | jobNames <- (List.append model.jobNames [name]) }
    DeleteJobName name -> noFx { model | jobNames <- List.filter (\jobname -> jobname /= name) model.jobNames }
    SetBuildOnBranchChange willTriggerBuild -> noFx { model | buildOnBranchChange <- willTriggerBuild }

noFx : a -> (a, Effects b)
noFx m = (m, Effects.none)

------------------------------------------------------------------------------
-- What things look like
------------------------------------------------------------------------------

view : Address Action -> JenkinsConfig -> Html
view address model = configView address model

configView : Address Action -> JenkinsConfig -> Html
configView address config =
  div []
      [
       div [ class "config-option-group" ]
           [ label [] [ text "Jenkins server" ]
           , input [ class "form-control"
                   , placeholder "Jenkins server root URL"
                   , type' "url"
                   , value config.serverURL ] []
           ]
      , div [class "config-option-group"]
        [ ul [] (List.map (\n -> li [] [jobNameView address n]) config.jobNames)
        , input [ class "form-control"
                , placeholder "Job name to add"
                , type' "text"
                , on "change" targetValue (Signal.message address << AddJobName)
                , value "" --, value (Maybe.withDefault config.newJobName "")
                ] []
        ]
      , div [class "config-option-group"] [
                label [] [ text "Trigger build on branch change"
                           , input [ class "form-control"
                                   , type' "checkbox"
                                   , checked config.buildOnBranchChange
                                   , onClick address (SetBuildOnBranchChange (not config.buildOnBranchChange)) ] []
                          ]
                ]
      ]

jobNameView : Address Action -> String -> Html
jobNameView address jobname =
  li []
        [ span [] [ text jobname ]
        , button [ onClick address (DeleteJobName jobname) ] [ text "delete" ]
        ]

onEnter : Address a -> a -> Attribute
onEnter address value =
    on "keydown"
      (Json.customDecoder keyCode is13)
      (\_ -> Signal.message address value)


is13 : Int -> Result String ()
is13 code =
  if code == 13 then Ok () else Err "not the right key code"

------------------------------------------------------------------------------
-- Backend interaction
------------------------------------------------------------------------------


-- getCalendarNames : Effects Action
-- getCalendarNames =
--   Http.get (Json.list Json.string) "/api/room_names"
--     |> Task.toMaybe
--     |> Task.map SetCalendarNames
--     |> Effects.task

-- getCalendarData : String -> Effects Action
-- getCalendarData roomName =
--   Http.get (decodeCalendarData roomName) (Http.url "/api/room_schedule" [("roomName", roomName)])
--     |> Task.toMaybe
--     |> Task.map (SetCalendarSlots roomName)
--     |> Effects.task


-- decodeCalendarData : String -> Json.Decoder (List TimeSlot)
-- decodeCalendarData roomName = Json.at ["calendars", roomName, "busy"] (Json.list decodeTimeSlot)

-- decodeTimeSlot : Json.Decoder TimeSlot
-- decodeTimeSlot = Json.object4 TimeSlot
--                  ("id" := Json.string)
--                  ("title" := Json.maybe Json.string)
--                  ("start" := decodeDate)
--                  ("end" := decodeDate)

-- decodeDate : Json.Decoder Date
-- decodeDate = Json.customDecoder Json.string Date.fromString

-- interactions with localStorage to save the model
port getStorage : Maybe JenkinsConfig

port setStorage : Signal JenkinsConfig
port setStorage = app.model

initialModel : JenkinsConfig
initialModel =
  Maybe.withDefault emptyConfig getStorage

------------------------------------------------------------------------------
-- How things start up and run
------------------------------------------------------------------------------

app = StartApp.start
      { init = (initialModel, Effects.none)
      , update = update
      , view = view
      , inputs = []
      }

main = app.html

-- Actually run the app's tasks
port tasks : Signal (Task.Task Never ())
port tasks = app.tasks