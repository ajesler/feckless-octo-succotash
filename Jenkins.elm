module Jenkins (Config, emptyConfig) where

type alias Config =
  { serverURL : String
  , jobNames : List String
  , buildOnBranchChange : Bool
  }

emptyConfig : Config
emptyConfig = { serverURL = "https://jenkins.example"
              , jobNames = [ "job1", "job2" ]
              , buildOnBranchChange = True
              }

--getJobConfig : String -> Effects Action
--getJobConfig jobName =