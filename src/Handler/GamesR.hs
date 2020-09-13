{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE TemplateHaskell       #-}
{-# LANGUAGE TypeFamilies          #-}
module Handler.GamesR where

import           Game.Game
import           Util.StateUtil
import           Marshalling
import           Util.HandlerUtil
import           Import
import           Text.Julius           (RawJS (..))
import           Control.Lens
import           Text.StringRandom
import           System.Random (randomRIO)

-- GET GAMES IN DB
getGamesR :: Handler Html
getGamesR = do
    -- Get games from database
    gameStateDBEntities <- runDB $ selectList [] [Desc GameStateEntityUpdatedAt]
    let gameStateEntities = map entityVal gameStateDBEntities
    
    -- List of paused games
    let gameStateEntitiesPaused = filter (\gs -> gs ^. gameStateEntityStatus == "Paused") gameStateEntities
    
    -- List of finished games
    let gameStateEntitiesWonOrLost = filter (\gs -> gs ^. gameStateEntityStatus == "Lost" || gs ^. gameStateEntityStatus == "Won") gameStateEntities

    defaultLayout $ do
            let (newGameFormId, joinGameFormId, joinGameId, bombCountField, widthField, heightField, randomSeedField) = variables
            setTitle "Minesweepskell"
            $(widgetFile "games")

-- INIT NEW GAME
postGamesR :: Handler Value
postGamesR = do
    app <- getYesod
    now <- liftIO getCurrentTime
    
    -- Generate a 5 character random game id
    randomString <- liftIO $ stringRandomIO "^[A-Z1-9]{5}$"
    let gameId_ = unpack randomString
    
    -- Get the in-memory state of ongoing games
    let tGames = games app
    
    -- Parse the newGameRequest
    newGameRequest <- (requireCheckJsonBody :: Handler NewGameRequest)

    -- Generate a new random seed if no seed has been provided, bounded because of JavaScript max number limit
    seed_ <- case newGameRequest ^. newGameRequestSeed of Just s -> return s
                                                          Nothing -> liftIO $ randomRIO (0, 900719925474099)

    -- create new channel
    channel_ <- newChan
    
    -- create new game
    let newGameState = newGame (newGameRequest ^. newGameRequestHeight, newGameRequest ^. newGameRequestWidth) (newGameRequest ^. newGameRequestBombCount) seed_ gameId_ now channel_

    -- write the new game into the in-memory state
    _ <- liftIO $ setGameStateForGameId tGames gameId_ newGameState
    returnJson $ gameStateToGameStateEntity newGameState 

variables :: (Text, Text, Text, Text, Text, Text, Text)
variables = ("js-newGameFormId", "js-joinGameFormId", "js-joingameid", "js-bombCountField", "js-widthField", "js-heightField", "js-randomSeedField")

showSize :: [Row] -> String
showSize b = showS (getHeightAndWidthFromBoard b) where showS (h,w) = show w ++ "x" ++ show h