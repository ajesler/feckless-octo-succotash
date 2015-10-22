module BranchManager where

import Jenkins
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Signal exposing (Signal, Address)
import Task
import Effects exposing (Effects, Never)
import String
import StartApp

type alias Model = {
  config : Maybe Jenkins.Config
}

type Action
  = NoOp
  | SetBranchName String
  | TriggerBuild String

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp -> noFx model
    SetBranchName name -> noFx model
    TriggerBuild name -> noFx model

noFx : a -> (a, Effects b)
noFx m = (m, Effects.none)

view : Address Action -> Model -> Html
view address model = 
  div [] [
    case model.config of
      Nothing     -> div [] [
        text "No config found"
      ]
      Just config -> div [] [
        (headerView address config)
        , div [] [ text (String.join ", " config.jobNames) ]
        , messagesView address model
        , branchNameInputView address
      ]
    , settingsLinkView address
  ]


headerView : Address Action -> Jenkins.Config -> Html
headerView address config =
  div [class "row text-center"] [
    a [ href config.serverURL
      , target "_blank"
      , id "serverLink" ] [
        img [ id "icon"
            , class "center-block"
            , src "images/icon48.png"
            ] []
      ]
  ]

messagesView : Address Action -> Model -> Html
messagesView address model =
  div [class "row"] [ p [ id "messages" ] [] ]

branchNameInputView : Address Action -> Html
branchNameInputView address =
  div [class "row"] [
    div [class "input-group"] [
      input [ type' "text", id "branchName", class "form-control", placeholder "branch-name" ] []
      , span [class "input-group-btn"] [
        button [id "updateButton", class "btn btn-primary"] [ text "Update Jobs" ]
      ]
    ]
  ]

settingsLinkView : Address Action -> Html
settingsLinkView address =
  div [] [
    a [ href "options.html?show_back_link" ] [ text "Settings" ]
  ]

port getStorage : Maybe Jenkins.Config

app = StartApp.start
      { init = ({ config = getStorage}, Effects.none)
      , update = update
      , view = view
      , inputs = []
      }

main = app.html

-- Actually run the app's tasks
port tasks : Signal (Task.Task Never ())
port tasks = app.tasks