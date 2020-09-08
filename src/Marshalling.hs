{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE NamedFieldPuns        #-}
{-# LANGUAGE NoImplicitPrelude     #-}
{-# LANGUAGE TypeFamilies          #-}
module Marshalling (
                    gameStateToGameStateEntity,
                    gameStateEntityToGameState,
                    statusEntityToStatus,
                    cellToCellEntity,
                    cellEntityToCell,
                    moveRequestToMove,
                    moveToMoveEntity,
                    moveEntityToMove
                    ) where

import           Data.Matrix
import           Import 
import           Game.Board
import           Game.Game

gameStateToGameStateEntity :: GameState -> GameStateEntity
gameStateToGameStateEntity state = GameStateEntity {
                                                      gameStateEntityBoard = boardToRows $ board state,
                                                      gameStateEntityMoves = map moveToMoveEntity $ moves state,
                                                      gameStateEntityBombCount = bombCount state,
                                                      gameStateEntitySeed = seed state,
                                                      gameStateEntityGameId = gameId state,
                                                      gameStateEntityCreatedAt = createdAt state,
                                                      gameStateEntityUpdatedAt = updatedAt state,
                                                      gameStateEntityStatus = show (status state),
                                                      gameStateEntityLastStartedAt = lastStartedAt state,
                                                      gameStateEntityTimeElapsed = timeElapsed state
                                                   } where boardToRows board = map (Row . map cellToCellEntity) (Data.Matrix.toLists board)

gameStateEntityToGameState :: GameStateEntity -> GameState
gameStateEntityToGameState entity = GameState {
                                      board = rowsToBoard $ gameStateEntityBoard entity,
                                      moves = map moveEntityToMove $ gameStateEntityMoves entity,
                                      bombCount = gameStateEntityBombCount entity,
                                      seed = gameStateEntitySeed entity,
                                      status = statusEntityToStatus $ gameStateEntityStatus entity,
                                      gameId = gameStateEntityGameId entity,
                                      createdAt = gameStateEntityCreatedAt entity,
                                      updatedAt = gameStateEntityUpdatedAt entity,
                                      lastStartedAt = gameStateEntityLastStartedAt entity,
                                      timeElapsed = gameStateEntityTimeElapsed entity
                                    } where rowsToBoard rows = Data.Matrix.fromLists $ map (map cellEntityToCell . rowCells) rows

statusEntityToStatus :: [Char] -> GameStatus
statusEntityToStatus "Ongoing" = Ongoing
statusEntityToStatus "Won"     = Won
statusEntityToStatus "Lost"    = Lost
statusEntityToStatus "Paused"  = Paused
statusEntityToStatus _         = undefined

cellToCellEntity :: Cell -> CellEntity
cellToCellEntity (Cell flagged revealed hasBomb neighbors (x,y)) = CellEntity {
                                                                     cellEntityCoordX = x,
                                                                     cellEntityCoordY = y,
                                                                     cellEntityIsFlagged = flagged,
                                                                     cellEntityIsRevealed = revealed,
                                                                     cellEntityHasBomb = hasBomb,
                                                                     cellEntityNeighboringBombs = neighbors
                                                                   }

cellEntityToCell :: CellEntity -> Cell
cellEntityToCell cellEntity = Cell {
                                isFlagged         = cellEntityIsFlagged cellEntity,
                                isRevealed        = cellEntityIsRevealed cellEntity,
                                hasBomb           = cellEntityHasBomb cellEntity,
                                neighboringBombs  = cellEntityNeighboringBombs cellEntity,
                                coordinate        = (cellEntityCoordX cellEntity, cellEntityCoordY cellEntity)
                              }


moveRequestToMove :: MoveRequest -> UTCTime -> Move
moveRequestToMove (MoveRequest "RevealAllNonFlagged" _ _) timeStamp = RevealAllNonFlagged timeStamp
moveRequestToMove (MoveRequest "Flag" (Just x) (Just y)) timeStamp  = Flag (x,y) timeStamp
moveRequestToMove (MoveRequest "Reveal"(Just x) (Just y)) timeStamp = Reveal (x,y) timeStamp
moveRequestToMove _ _ = undefined

moveToMoveEntity :: Move -> MoveEntity
moveToMoveEntity (Flag (x,y) timeStamp)           = MoveEntity "Flag" (Just x) (Just y) timeStamp
moveToMoveEntity (Reveal (x,y) timeStamp)         = MoveEntity "Reveal" (Just x) (Just y) timeStamp
moveToMoveEntity (RevealAllNonFlagged timeStamp)  = MoveEntity "RevealAllNonFlagged" Nothing Nothing timeStamp

moveEntityToMove :: MoveEntity -> Move
moveEntityToMove (MoveEntity "Flag" (Just x) (Just y) timeStamp)    = Flag (x,y) timeStamp
moveEntityToMove (MoveEntity "Reveal" (Just x) (Just y) timeStamp)  = Reveal (x,y) timeStamp
moveEntityToMove (MoveEntity "RevealAllNonFlagged" _ _ timeStamp)   = RevealAllNonFlagged timeStamp
moveEntityToMove _   = undefined 