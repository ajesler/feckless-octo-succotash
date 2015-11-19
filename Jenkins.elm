module Jenkins (Config, Job, emptyConfig, getJobs) where

import Http exposing (send, empty, defaultSettings
    , Response, Value(..)
    , Error(..), RawError(..))
import Task exposing (Task, andThen, mapError, succeed, fail)
import String exposing (join)
import Effects exposing (Effects, Never)
import Regex

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

updateJobs : Config -> String -> Effects (Maybe (List Job))
updateJobs config newBranch =
  List.map (jobConfigString (jobConfigUrl config)) config.jobNames
    |> Task.sequence
    |> Task.toMaybe
    |> Task.map (Maybe.map (List.filterMap identity))
    |> Effects.task

updateJob : String -> String -> Task String String
updateJob jobName branchName =
  succeed (jobConfigUrl jobName)
  `andThen` (mapError (always "Could not load job") << jobConfigString)
  -- get config
  -- update branch name
  -- post result
  -- on success,

getBranchNameForJob : Config -> String -> Task.Task Http.Error (Maybe Job)
getBranchNameForJob config jobName =
  jobConfigString (jobConfigUrl config jobName)
    |> Task.toMaybe
    |> Task.map (Maybe.map (Job jobName) << extractBranchName)

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
      Regex.find (Regex.AtMost 1) jenkinsBranchRegex input -- [RegexMatch]
        |> List.concatMap .submatches  -- [Just a]
        |> List.filterMap identity
        |> List.head

updateBranchNameInXml : String -> String
updateBranchNameInXml xml =
  Regex.replace Regex.All jenkinsBranchRegex (\_ -> "newBranch") xml

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
