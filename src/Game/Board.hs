{-# LANGUAGE TemplateHaskell #-}

module Game.Board
  ( generateBoard,
    reveal,
    revealAllNonFlaggedCells,
    flagCell,
    checkLost,
    checkWon,
    coordinateToCellNumber,
    getDimensionsForBoard,
    Coordinate,
    Dimension,
    Board,
    Cell (..),
    isFlagged,
    isRevealed,
    hasBomb,
    neighboringBombs,
    coordinate,
    inBounds,
  )
where

import Control.Lens
import Data.List
import Data.Matrix
import Data.Matrix.Lens (elemAt, flattened, size)
import System.Random
import System.Random.Shuffle

type Dimension = (Int, Int)

type Coordinate = (Int, Int)

data Cell = Cell
  { _isFlagged :: Bool,
    _isRevealed :: Bool,
    _hasBomb :: Bool,
    _neighboringBombs :: Int,
    _coordinate :: Coordinate
  }
  deriving (Show, Eq)

makeLenses ''Cell

type Board = Matrix Cell

-- Generates a Minesweeper Board with a given dimension, number of bombs and random seed
generateBoard :: Dimension -> Int -> Int -> Board
generateBoard (h, w) bombCount seed =
  matrix
    h
    w
    ( \(i, j) ->
        Cell
          { _isRevealed = False,
            _isFlagged = False,
            -- the cell has a bomb on it if the cell number is part of the bomb cells
            _hasBomb = coordinateToCellNumber (i, j) (h, w) `elem` bombPos,
            -- the amount of neighboring bombs is equal to:
            -- the length of the intersection between the neighbouring cell numbers & the bomb cell numbers
            _neighboringBombs = length $ map toCellNumber (neighbourCells (i, j) (h, w)) `intersect` bombPos,
            -- the cells coordinate
            _coordinate = (i, j)
          }
    )
  where
    -- initialize randomizer with seed
    rand = mkStdGen seed
    -- calculate number of total cells on the board
    numCells = h * w
    -- calculate the cell numbers with bombs
    bombPos = take bombCount (shuffle' [1 .. numCells] numCells rand)
    -- helper function to slim down the neighboring Bomb calculation
    toCellNumber x = coordinateToCellNumber x (h, w)

-- helper function to set a specific cells isRevealed flag to True
setCellToRevealed :: Board -> Coordinate -> Board
setCellToRevealed board c = board & elemAt c . isRevealed .~ True

-- wrapper for the reveal actions, if a cell is not revealed yet, reveal it, otherwise try a quick reveal
reveal :: Board -> Coordinate -> Board
reveal board c = if board ^. elemAt c . isRevealed then quickReveal board c else revealCell board c

-- Reveals a cell at a given coordinate for a given Board
-- Rule explanation: will also reveal any direct neighbouring Cells which have no bomb and their neighbour cells if the have 0 neighboring bombs
revealCell :: Board -> Coordinate -> Board
revealCell board c = resultBoard
  where
    -- dimension of the board
    dim = getDimensionsForBoard board
    resultBoard = case board ^. elemAt c of
      -- case of a unrevealed cell with no neighboring bombs and which also does not contain a bomb
      -- in this case we want to reveal the neighboring cells as well
      (Cell _ True _ _ _) -> board
      (Cell True _ _ _ _) -> board
      (Cell False False False 0 _) -> neighboursBoard
        where
          -- the board with the cell (i,j) set to revealed
          cellBoard = setCellToRevealed board c
          -- all the direct neighbours of the cell (i,j)
          neighbours = neighbourCells c dim
          -- fold over the list of neighbours and recursively call revealCell for each one
          neighboursBoard = foldl revealCell cellBoard neighbours
      -- In any other case just reveal the cell at (i,j)
      _ -> setCellToRevealed board c

-- Quick reveal
-- If a cell is revealed, has more than one neighboring bomb and the bomb count matches the amount of flagged neighbors all non flagged neighbours can bo quick revealed
quickReveal :: Board -> Coordinate -> Board
quickReveal board c = resultBoard
  where
    dim = getDimensionsForBoard board
    cellIsRevealed = board ^. elemAt c . isRevealed
    neighbourCoordinates = neighbourCells c dim
    neighbours = filter (\cell -> cell ^. coordinate `elem` neighbourCoordinates) (toList board)
    bombNeighbourCount = board ^. elemAt c . neighboringBombs
    nonFlaggedNeighboursCoordinates = map _coordinate $ filter (\x -> not (x ^. isFlagged)) neighbours
    flaggedNeighboursCount = length $ filter (^. isFlagged) neighbours
    -- move is only valid if c is revealed, has neighboring bombs and if the neighboringBombs match the number of flagged neighbours
    isValidMove = cellIsRevealed && bombNeighbourCount > 0 && bombNeighbourCount == flaggedNeighboursCount
    --if the move is valid reveal all neighbour cells otherwise return the initial board
    resultBoard = if isValidMove then foldl setCellToRevealed board nonFlaggedNeighboursCoordinates else board

-- Reveals all cells which have not been flagged
revealAllNonFlaggedCells :: Board -> Board
revealAllNonFlaggedCells board = board & flattened . filtered (not . _isFlagged) . isRevealed .~ True

-- Toggles the isFlagged state of a cell at a given coordinate for a given board, will only flag cell if cell was not already revealed & if enough flags are left
flagCell :: Board -> Coordinate -> Board
flagCell board c =
  if performMove
    then board & elemAt c . isFlagged .~ updatedValue
    else board
  where
    flagged = board ^. elemAt c . isFlagged
    revealed = board ^. elemAt c . isRevealed
    updatedValue = not flagged
    performMove = (hasFlagsLeft board || flagged) && not revealed

-- Checks if a board has flags left to be placed (less flags than bombs)
hasFlagsLeft :: Board -> Bool
hasFlagsLeft board = bombCount > flagCount
  where
    bombCount = length $ filter _hasBomb (toList board)
    flagCount = length $ filter _isFlagged (toList board)

-- Checks if any bomb has been revealed
checkLost :: Board -> Bool
checkLost board = any (\c -> c ^. isRevealed && c ^. hasBomb) (toList board)

-- Checks if all non bomb fields are revealed OR if all bombs have been flagged
checkWon :: Board -> Bool
checkWon board = all _isRevealed $ filter (not . _hasBomb) (toList board)

-- Calculates the cell number of a given XY-Coordinate for a given Board size
-- will also calculate out of bounds cells if out of bounds coordinates are provided
coordinateToCellNumber :: Coordinate -> Dimension -> Int
coordinateToCellNumber (i, j) (_, w) = (i -1) * w + j

-- Checks if a coordinate is inBounds of a given Board size
inBounds :: Coordinate -> Dimension -> Bool
inBounds (i, j) (h, w) = (i > 0) && (i <= h) && (j > 0) && (j <= w)

-- Calculates all inBounds (including diagonal) neighbour cells of a given cell
neighbourCells :: Coordinate -> Dimension -> [Coordinate]
neighbourCells (i, j) d = filter (`inBounds` d) theoreticalNeighbors
  where
    theoreticalNeighbors =
      [ (i -1, j -1), -- top-left
        (i -1, j), -- top
        (i -1, j + 1), -- top-right
        (i, j -1), -- left
        (i, j + 1), -- right
        (i + 1, j -1), -- bottom-left
        (i + 1, j), -- bottom
        (i + 1, j + 1) -- bottom-right
      ]

-- Returns the Dimension of a given board
getDimensionsForBoard :: Board -> Dimension
getDimensionsForBoard board = board ^. size
