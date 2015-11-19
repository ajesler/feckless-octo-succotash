module Jenkins (Config, Job, emptyConfig, getJobs, updateJobConfigs) where

import Http exposing (send, empty, defaultSettings
    , Response, Value(..)
    , Error(..), RawError(..))
import Task exposing (Task, andThen, mapError, succeed, fail)
import String exposing (join)
import Effects exposing (Effects, Never)
import Regex

jenkinsBranchRegex : Regex.Regex
jenkinsBranchRegex = Regex.regex "<hudson\\.plugins\\.git\\.BranchSpec>\\s+<name>(.*?)</name>\\s+</hudson\\.plugins\\.git\\.BranchSpec>"

type alias Config =
  { serverURL : String
  , jobNames : List String
  , buildOnBranchChange : Bool
  }

type alias Job = {
  name : String
  , branch : String
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

updateJobConfigs : Config -> String -> Effects (Maybe (List String))
updateJobConfigs config branchName =
  List.map (updateJobConfig config branchName) config.jobNames
    |> Task.sequence
    |> Task.toMaybe -- Maybe (List String)
    |> Effects.task

updateJobConfig : Config -> String -> String -> Task Http.Error String
updateJobConfig config branchName jobName =
  let
    configUrl = jobConfigUrl config jobName
  in
    jobConfigString configUrl
      `andThen` \xml ->
    succeed (replaceBranchName xml branchName)
      `andThen` \updatedXml ->
    postJobConfigString configUrl updatedXml

getBranchNameForJob : Config -> String -> Task.Task Http.Error (Maybe Job)
getBranchNameForJob config jobName =
  jobConfigString (jobConfigUrl config jobName)
    |> Task.toMaybe
    |> Task.map (Maybe.map (Job jobName) << extractBranchName)

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

jobConfigUrl : Config -> String -> String
jobConfigUrl config jobName =
  String.join "/" [config.serverURL, "view/All/job", jobName, "config.xml"]

extractBranchName : Maybe String -> Maybe String
extractBranchName xml =
  case xml of
    Nothing -> Nothing
    Just input ->
      Regex.find (Regex.AtMost 1) jenkinsBranchRegex input
        |> List.concatMap .submatches
        |> List.filterMap identity
        |> List.head

replaceBranchName : String -> String -> String
replaceBranchName xml branchName =
  Regex.replace Regex.All jenkinsBranchRegex (\_ -> branchName) xml

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
