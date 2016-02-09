module Jenkins (Config, Job, emptyConfig, getJobs, updateJobEffects, jobUrl) where

import Http exposing (send, empty, defaultSettings
    , Response, Value(..)
    , Error(..), RawError(..))
import Task exposing (Task, andThen, mapError, succeed, fail)
import String exposing (join)
import Effects exposing (Effects, Never)
import Regex

jenkinsBranchRegex : Regex.Regex
jenkinsBranchRegex = Regex.regex "<hudson\\.plugins\\.git\\.BranchSpec>\\s*<name>(.*?)</name>\\s*</hudson\\.plugins\\.git\\.BranchSpec>"

type alias Config =
  { serverURL : String
  , jobNames : List String
  , buildOnBranchChange : Bool
  }

type alias Job = {
  name : String
  , branch : String
  , updateBranch : Bool
}

type alias JobUpdateResult = {
  name : String
  , branch : String
  , success : Bool
  , error : String
}

emptyConfig : Config
emptyConfig = { serverURL = "https://jenkins.example"
              , jobNames = [ "job1", "job2" ]
              , buildOnBranchChange = True
              }

getJobs : Config -> Effects (Maybe (List Job))
getJobs config =
  List.map (getBranchNameForJob config) config.jobNames
   |> Task.sequence
   |> Task.toMaybe
   |> Task.map (Maybe.map (List.filterMap identity))
   |> Effects.task

updateJobEffects : Config -> String -> Job -> Effects (Maybe Job)
updateJobEffects config branch job =
  updateJob config branch job
    |> Task.toMaybe
    |> Effects.task

updateJob : Config -> String -> Job -> Task Http.Error Job
updateJob config branchName job =
  let
    configUrl = jobConfigUrl config job.name
  in
    jobConfigString configUrl
      `andThen` \xml ->
    succeed (replaceBranchName xml branchName)
      `andThen` \updatedXml ->
    postJobConfigString configUrl updatedXml
      `andThen` \_ ->
    triggerBuild config job -- will not update the job in UI if this fails..
      `andThen`
    (succeed << always (Job job.name branchName job.updateBranch))

triggerBuild : Config -> Job -> Task.Task Http.Error String
triggerBuild config job =
  if config.buildOnBranchChange then
    let
      request = {
        verb = "POST"
        , headers = [("Access-Control-Allow-Credentials", "true")]
        , url = (jobBuildUrl config job.name)
        , body = Http.empty
      }
    in
      Task.mapError promoteError (Http.send Http.defaultSettings request)
        `andThen` handleResponse succeed
  else
    succeed "not triggering a build"

getBranchNameForJob : Config -> String -> Task.Task Http.Error (Maybe Job)
getBranchNameForJob config jobName =
  jobConfigString (jobConfigUrl config jobName)
    |> Task.toMaybe
    |> Task.map (Maybe.map (createJob jobName) << extractBranchName)

postJobConfigString : String -> String -> Task.Task Http.Error String
postJobConfigString url xml =
  let
    request = {
      verb = "POST"
      , headers = [("Access-Control-Allow-Credentials", "true")]
      , url = url
      , body = Http.string xml
    }
  in
    Task.mapError promoteError (Http.send Http.defaultSettings request)
      `andThen` handleResponse succeed

jobConfigString : String -> Task.Task Http.Error String
jobConfigString url =
  let request =
        { verb = "GET"
        , headers = [("Access-Control-Allow-Credentials", "true")]
        , url = url
        , body = Http.empty
        }
  in
      Task.mapError promoteError (Http.send Http.defaultSettings request)
        `andThen` handleResponse succeed

createJob : String -> String -> Job
createJob jobName branchName =
  Job jobName branchName True

jobUrl : Config -> String -> String
jobUrl config jobName =
  String.join "/" [config.serverURL, "view/All/job", jobName]

jobConfigUrl : Config -> String -> String
jobConfigUrl config jobName =
  String.join "/" [config.serverURL, "view/All/job", jobName, "config.xml"]

jobBuildUrl : Config -> String -> String
jobBuildUrl config jobName =
  String.join "/" [config.serverURL, "job", jobName, "build"]

extractBranchName : Maybe String -> Maybe String
extractBranchName xml =
  case xml of
    Nothing -> Nothing
    Just input ->
      Regex.find (Regex.AtMost 1) jenkinsBranchRegex input
        |> List.concatMap .submatches
        |> List.filterMap identity
        |> List.head

buildNewMatchSection : String -> String
buildNewMatchSection branch =
  "<hudson.plugins.git.BranchSpec><name>" ++ branch ++ "</name></hudson.plugins.git.BranchSpec>"

replaceBranchName : String -> String -> String
replaceBranchName xml branchName =
  Regex.replace Regex.All jenkinsBranchRegex (\_ -> buildNewMatchSection branchName) xml

-- FROM https://github.com/evancz/elm-http/blob/master/src/Http.elm

handleResponse : (String -> Task Error a) -> Response -> Task Error a
handleResponse handle response =
  if 200 <= response.status && response.status < 300 then
      case response.value of
        Text str ->
            handle str
        _ ->
            fail (UnexpectedPayload "Response body is a blob, expecting a string.")
  else
      fail (BadResponse response.status response.statusText)

promoteError : RawError -> Error
promoteError rawError =
  case rawError of
    RawTimeout -> Timeout
    RawNetworkError -> NetworkError
