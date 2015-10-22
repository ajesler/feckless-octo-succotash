module App where

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
import Date exposing (..)
import Time


------------------------------------------------------------------------------
-- Things we're working with here
------------------------------------------------------------------------------

type alias Config =
  { serverURL : String
  , jobNames : List String
  , buildOnBranchChange : Bool
  }

type alias Model = Config

emptyModel : Model
emptyModel = emptyConfig

emptyConfig : Config
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

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp -> noFx model
    AddJobName name -> noFx { model | jobNames <- (name :: model.jobNames) }

noFx : a -> (a, Effects b)
noFx m = (m, Effects.none)

------------------------------------------------------------------------------
-- What things look like
------------------------------------------------------------------------------

view : Address Action -> Model -> Html
view address model = configView address model


configView : Address Action -> Config -> Html
configView address config =
  div []
      [
       div [ class "input-group" ]
           [ label [] [ text "Jenkins server" ]
           , input [ class "form-control"
                   , placeholder "Jenkins server root URL"
                   , type' "url"
                   , value config.serverURL ] []
           ]
      , ul [] (List.map (\n -> li [] [jobNameView address n]) config.jobNames)
      , input [ class "form-control"
              , placeholder "Job name to add"
              , type' "text"
              , on "change" targetValue (Signal.message address << AddJobName)
              , value "" --, value (Maybe.withDefault config.newJobName "")
              ] []
      , label [] [ text "Trigger build on branch change"
                 , input [ class "form-control"
                         , type' "checkbox"
                         , checked config.buildOnBranchChange ] []
                ]
      ]

jobNameView : Address Action -> String -> Html
jobNameView address jobname =
  span [] [ text jobname ]


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

------------------------------------------------------------------------------
-- How things start up and run
------------------------------------------------------------------------------

app = StartApp.start
      { init = (emptyModel, Effects.none)
      , update = update
      , view = view
      , inputs = []
      }

main = app.html

-- Actually run the app's tasks
port tasks : Signal (Task.Task Never ())
port tasks = app.tasks
