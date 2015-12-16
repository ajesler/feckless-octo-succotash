module OptionsEditor where

import Common exposing (..)
import Jenkins
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Signal exposing (Signal, Address)
import Task
import Effects exposing (Effects, Never)
import StartApp


------------------------------------------------------------------------------
-- Things we're working with here
------------------------------------------------------------------------------
type alias JenkinsConfig = Jenkins.Config

------------------------------------------------------------------------------
-- Things we can do
------------------------------------------------------------------------------

type Action
  = NoOp
  | SetServerURL String
  | AddJobName String
  | DeleteJobName String
  | SetBuildOnBranchChange Bool

update : Action -> JenkinsConfig -> (JenkinsConfig, Effects Action)
update action model =
  case action of
    NoOp -> noFx model
    SetServerURL url -> noFx { model | serverURL = url }
    AddJobName name -> noFx { model | jobNames = (List.append model.jobNames [name]) }
    DeleteJobName name -> noFx { model | jobNames = List.filter (\jobname -> jobname /= name) model.jobNames }
    SetBuildOnBranchChange willTriggerBuild -> noFx { model | buildOnBranchChange = willTriggerBuild }

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
                   , value config.serverURL
                   , on "change" targetValue (Signal.message address << SetServerURL)] []
           ]
      , div [class "config-option-group"]
        [ ul [] (List.map (\n -> li [] [jobNameView address n]) config.jobNames)
        , input [ class "form-control"
                , placeholder "Job name to add"
                , type' "text"
                , on "change" targetValue (Signal.message address << AddJobName)
                , value ""
                ] []
        ]
      , div [class "checkbox"] [
                label [] [ input [ type' "checkbox"
                                   , checked config.buildOnBranchChange
                                   , onClick address (SetBuildOnBranchChange (not config.buildOnBranchChange)) ] []
                            , text "Trigger build on branch change"
                          ]
                ]
      ]

jobNameView : Address Action -> String -> Html
jobNameView address jobname =
  li [ class "job-container" ]
        [ span [ class "job-name" ] [ text jobname ]
        , button [
          class "btn btn-warning btn-xs"
          , onClick address (DeleteJobName jobname) ] [ text "delete" ]
        ]

------------------------------------------------------------------------------
-- Backend interaction
-- interactions with localStorage to save the model
------------------------------------------------------------------------------

port getStorage : Maybe JenkinsConfig

port setStorage : Signal JenkinsConfig
port setStorage = app.model

initialModel : JenkinsConfig
initialModel =
  Maybe.withDefault Jenkins.emptyConfig getStorage

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
