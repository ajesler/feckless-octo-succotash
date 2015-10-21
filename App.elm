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

type alias Model =
  { calendar : Maybe String
  , calendarNames : List String
  , busy : Bool
  , timeSlots : Maybe (List TimeSlot)
  }

type SlotStatus = Booked | Pending

type alias TimeSlot =
  { id : String
  , description : Maybe String
  , start : Date
  , end : Date
  }

emptyModel : Model
emptyModel =
  { calendar = Nothing
  , calendarNames = []
  , busy = False
  , timeSlots = Nothing
  }

nextCalendar : Model -> Maybe String
nextCalendar model =
  case model.calendar of
    Nothing -> List.head model.calendarNames
    Just c  -> elementAfter c model.calendarNames

elementAfter : a -> List a -> Maybe a
elementAfter y stuff =
  let go xs = case xs of
    [] -> Nothing
    [x] -> Just x
    a::(b::cs) -> if a == y then Just b else go (b::cs)
  in go (stuff ++ stuff)

slotDurationMinutes : TimeSlot -> Int
slotDurationMinutes slot =
  let mins d = Date.toTime d |> Time.inMinutes |> floor
  in (mins slot.end) - (mins slot.start)


------------------------------------------------------------------------------
-- Things we can do
------------------------------------------------------------------------------

type Action
  = NoOp
  | SelectCalendar (Maybe String)
  | NextCalendar
  | SetCalendarNames (Maybe (List String))
  | SetCalendarSlots String (Maybe (List TimeSlot))

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp -> noFx model

    SelectCalendar maybeCal ->
      if maybeCal == model.calendar then
        noFx model
      else
        ({ model | calendar <- maybeCal, timeSlots <- Nothing },
         case maybeCal of
           Just c -> getCalendarData c
           _      -> Effects.none)

    NextCalendar ->
      update (SelectCalendar (nextCalendar model)) model

    SetCalendarNames (Just names)  ->
      let newModel = { model | calendarNames <- names }
      in case newModel.calendar of
           Nothing -> update NextCalendar newModel
           -- TODO: ensure calendar is in calendarNames
           _       -> noFx newModel

    SetCalendarNames Nothing  ->
      (model, Effects.none)

    SetCalendarSlots calendar maybeSlots ->
      if Just calendar == model.calendar then
         noFx { model | timeSlots <- maybeSlots }
      else
        noFx model

noFx : a -> (a, Effects b)
noFx m = (m, Effects.none)

------------------------------------------------------------------------------
-- What things look like
------------------------------------------------------------------------------

view : Address Action -> Model -> Html
view address model =
  div []
      [ calendarHeader address model
      , div [ class "main-box" ]
            [ case model.timeSlots of
                Nothing    -> div [ class "loading" ] [ text "Loading..." ]
                Just slots -> div [ class "calendar-entries" ]
                              (List.map (calendarEntry address) slots)
            ]
      ]

isJust : Maybe a -> Bool
isJust m = case m of
             Just _ -> True
             _      -> False

calendarHeader : Address Action -> Model -> Html
calendarHeader address model =
  div [ classList [("heading", True), ("pink", model.busy), ("green", not model.busy)] ]
      [ div [ class "button right arrow",
              onClick address NextCalendar ] []
      , h1 [] [ text (Maybe.withDefault "No calendar" (model.calendar)) ]
      ]

minutesToPixels : Int -> Int
minutesToPixels m = m * 2

calendarEntry : Address Action -> TimeSlot -> Html
calendarEntry address slot =
  div [ class "calendar-entry pink"
      , style [ ("height", toString (minutesToPixels (slotDurationMinutes slot)) ++ "px" )]
      ]
      [ text (Maybe.withDefault "Mystery meeting" slot.description) ]


------------------------------------------------------------------------------
-- Backend interaction
------------------------------------------------------------------------------

getCalendarNames : Effects Action
getCalendarNames =
  Http.get (Json.list Json.string) "/api/room_names"
    |> Task.toMaybe
    |> Task.map SetCalendarNames
    |> Effects.task

getCalendarData : String -> Effects Action
getCalendarData roomName =
  Http.get (decodeCalendarData roomName) (Http.url "/api/room_schedule" [("roomName", roomName)])
    |> Task.toMaybe
    |> Task.map (SetCalendarSlots roomName)
    |> Effects.task


decodeCalendarData : String -> Json.Decoder (List TimeSlot)
decodeCalendarData roomName = Json.at ["calendars", roomName, "busy"] (Json.list decodeTimeSlot)

decodeTimeSlot : Json.Decoder TimeSlot
decodeTimeSlot = Json.object4 TimeSlot
                 ("id" := Json.string)
                 ("title" := Json.maybe Json.string)
                 ("start" := decodeDate)
                 ("end" := decodeDate)

decodeDate : Json.Decoder Date
decodeDate = Json.customDecoder Json.string Date.fromString

------------------------------------------------------------------------------
-- How things start up and run
------------------------------------------------------------------------------

app = StartApp.start
      { init = (emptyModel, getCalendarNames)
      , update = update
      , view = view
      , inputs = []
      }

main = app.html

-- Actually run the app's tasks
port tasks : Signal (Task.Task Never ())
port tasks = app.tasks
