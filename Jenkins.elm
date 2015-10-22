module Jenkins (Config) where

type alias Config =
  { serverURL : String
  , jobNames : List String
  , buildOnBranchChange : Bool
  }