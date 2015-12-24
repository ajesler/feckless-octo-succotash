module BranchManager where

import Common exposing (onEnter)
import Jenkins exposing (Config, Job, emptyConfig, getJobs, updateJobEffects)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Signal exposing (Signal, Address)
import Task
import Effects exposing (Effects, Never)
import StartApp
import Task exposing (Task, andThen, mapError, succeed, fail)
import String exposing (isEmpty)

-- DATA TYPES

type alias Model = {
  config : Maybe Config
  , branchName : String
  , jobs : List Job
}

-- ACTIONS

type Action
  = NoOp
  | EditedBranchName String
  | ToggleJob String
  | ApplyBranchName
  | JobsUpdated (Maybe (List Job))
  | JobUpdated (Maybe Job)
  | FoundJobs (List Job)

update : Action -> Model -> (Model, Effects Action)
update action model =
  case action of
    NoOp -> noFx model
    EditedBranchName name -> noFx { model | branchName = name }
    ToggleJob name ->
      let toggleUpdateBranch job =
        if job.name == name
          then { job | updateBranch = not job.updateBranch }
          else job
      in
        noFx { model | jobs = List.map toggleUpdateBranch model.jobs }
    ApplyBranchName -> applyNewBranchName model
    JobsUpdated jobs ->
      case jobs of
        Nothing -> noFx model
        Just updatedJobs ->
          let
            unchangedJobs = List.filter (\j -> not (List.member j updatedJobs)) model.jobs
            mergedJobs = List.append unchangedJobs updatedJobs |> List.sortBy .name
          in
            noFx { model | jobs = mergedJobs }
    JobUpdated job ->
      case job of
        Nothing -> noFx model
        Just updatedJob ->
          let
            unchangedJobs = List.filter (\j -> j.name /= updatedJob.name) model.jobs
            mergedJobs = updatedJob :: unchangedJobs |> List.sortBy .name
          in
            noFx { model | jobs = mergedJobs }
    FoundJobs jobs -> noFx { model | jobs = List.sortBy .name jobs }

noFx : a -> (a, Effects b)
noFx m = (m, Effects.none)

updateJobs : Model -> Effects Action
updateJobs model =
  case model.config of
    Nothing -> Effects.none
    Just config -> getJobs config
                     |> Effects.map (FoundJobs << Maybe.withDefault [])

applyNewBranchName : Model -> (Model, Effects Action)
applyNewBranchName model =
  case model.config of
    Nothing -> ({ model | branchName = "" }, Effects.none)
    Just config ->
      if isEmpty model.branchName then
        noFx { model | branchName = "" }
      else
        let
          jobsToUpdate = List.filter (\job -> job.updateBranch) model.jobs
          effect = List.map (updateJobEffects config model.branchName) jobsToUpdate
                      |> List.map (Effects.map (JobUpdated))
                      |> Effects.batch
        in
          ({ model | branchName = "" }, effect)

-- VIEWS

view : Address Action -> Model -> Html
view address model =
  div [] [
    case model.config of
      Nothing     -> div [] [
        text "No config found"
      ]
      Just config -> div [] [
        headerView address config
        --, div [] [ text (String.join ", " config.jobNames) ]
        , messagesView address model
        , jobsView address model.jobs
        , branchNameInputView address model
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

jobsView : Address Action -> List Job -> Html
jobsView address jobs =
  table [class "table"] ([
    tr [] [
      th [] []
      , th [] [ text "Job Name" ]
      , th [] [ text "Branch" ]
    ]
  ] ++ (List.map (jobRowView address) jobs))

jobRowView : Address Action -> Job -> Html
jobRowView address job =
  tr [] [
    td [] [
      input [ type' "checkbox"
              , checked job.updateBranch
              , onClick address (ToggleJob job.name) ] []
    ]
    , td [] [ text job.name ]
    , td [] [ text job.branch ]
  ]

messagesView : Address Action -> Model -> Html
messagesView address model =
  div [class "row"] [ p [ id "messages" ] [] ]

branchNameInputView : Address Action -> Model -> Html
branchNameInputView address model =
  div [class "row"] [
    div [class "input-group"] [
      input [ type' "text"
            , id "branchName"
            , class "form-control"
            , placeholder "branch-name"
            , value model.branchName
            , onEnter address ApplyBranchName
            , (on "input" targetValue (Signal.message address << EditedBranchName)) ] []
      , span [class "input-group-btn"] [
        button [id "updateButton"
                , class "btn btn-primary"
                , onClick address ApplyBranchName ] [ text "Update Jobs" ]
      ]
    ]
  ]

settingsLinkView : Address Action -> Html
settingsLinkView address =
  div [] [
    a [ href "options.html?show_back_link" ] [ text "Settings" ]
  ]

-- APP INITIALIZATION

port getStorage : Maybe Jenkins.Config

app = let
    initialModel = { config = getStorage, branchName = "", jobs = [] }
  in
    StartApp.start
        { init = (initialModel, updateJobs initialModel)
        , update = update
        , view = view
        , inputs = []
        }

main = app.html

-- Actually run the app's tasks
port tasks : Signal (Task.Task Never ())
port tasks = app.tasks