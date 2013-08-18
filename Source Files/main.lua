-- Eternal caterpillar, a snake remake.
-- @author Di Tran
-- @version 1.0
-- @since July 29 2013
require 'socket'
require 'Tserial'

function love.load()
  -- ** IMAGES, FUNCTIONS, VARIABLES **
  -- IMAGES
  cellPic = love.graphics.newImage("cellPic.png")
  headUp = love.graphics.newImage("headUp.png")
  headRight = love.graphics.newImage("headRight.png")
  headDown = love.graphics.newImage("headDown.png")
  headLeft = love.graphics.newImage("headLeft.png")
  fruitPic = love.graphics.newImage("fruitPic.png")
  bg = love.graphics.newImage("bg2.png") -- bg.jpg
  arrow = love.graphics.newImage("Arrow.png")
  
  -- FONTS
  littleFont = love.graphics.newFont("led_display-7.ttf", 16)
  bigFont = love.graphics.newFont("led_display-7.ttf", 36)
  border = love.graphics.newImage("border.png")
  
  -- VARIABLES
  cellSize = 20 -- change this value if image resolution of cellPic changes.
  actualWidth = love.graphics.getWidth()
  actualHeight = love.graphics.getHeight()
  screenWidth = actualWidth - 40
  screenHeight = actualHeight - 40
  cellsWide = screenWidth / cellSize
  cellsTall = screenHeight / cellSize
  arrowX = 70 -- holds coordinates to the arrow cursor
  arrowY = 159
  
  snakeStartX = 1
  snakeStartY = 1
  pointTable = {} -- stores coordinate points of the playing area
  indexTable = {} -- stores indices to pointTable
  
  head = headDown -- stores direction of snake head
  
  -- AUDIO
  crunch = love.audio.newSource("crunch.ogg")
  arrowSound = love.audio.newSource("select.ogg")
  
  Cell = {}
  Snake = {}
  
  -- code for reading in highscores. Currently not working.
  saveFile = love.filesystem.newFile("save.txt")
  saveFile:open("r")
  highScore = saveFile:read()
  saveFile:close()
  
  -- object cell. Each element of the snake has cells for its body
  -- @param cellX X coordinate
  -- @param cellY Y coordinate
  -- @return obj local data holding object and its methods
  function Cell:New(cellX, cellY)
    local obj = {}
    obj.cellX = cellX
    obj.cellY = cellY
    
    function obj:getX()
      return self.cellX
    end
    
    function obj:getY()
      return self.cellY
    end
    
    -- compares two cell's coordinates
    -- @return boolean on if they're the same or not
    function obj:isSameCell(passCell)
      local compareX = passCell:getX()
      local compareY = passCell:getY()
      return (self.cellX == compareX
      and self.cellY == compareY)
    end
    
    -- gets a hash value of its coordinates
    -- returns number
    function obj:getHash()
      return pairToNum(cellX, cellY)
    end
    
    return obj
  end -- end Cell:New
  
  -- object representing the snake.
  -- cell at position 2 is the tail, cell at last position is the head
  -- cell at position 1 is the "GHOST CELL." It is a placeholder that
  -- is drawn when the snake eats a fruit.
  --@return obj representing itself
  function Snake:New()
    local obj = {}
    
    -- add new cell to itself, update points counter
    -- and the highscore
    function obj:eat(passFruit)
      table.insert(self, 1, passFruit)
      points = points + 1
      updateHighScore()
    end -- end function obj:eat
    
    -- check the moving direction, then create a new cell in
    -- the appropiate direction and remove the last cell
    function obj:move(moving)
      if moving == "up" then
        local newX = self[#self]:getX()
        local newY = self[#self]:getY()
        table.insert(self, Cell:New(newX, newY - 1))
        table.remove(self, 1)
      elseif moving == "down"  then
        local newX = self[#self]:getX()
        local newY = self[#self]:getY()
        table.insert(self, Cell:New(newX, newY + 1))
        table.remove(self, 1)
      elseif moving == "left" then
        local newX = self[#self]:getX()
        local newY = self[#self]:getY()
        table.insert(self, Cell:New(newX - 1, newY))
        table.remove(self, 1)
      elseif moving == "right" then
        local newX = self[#self]:getX()
        local newY = self[#self]:getY()
        table.insert(self, Cell:New(newX + 1, newY))
        table.remove(self, 1)
      end -- end ifelse statements
      
    end -- end function obj:move
    
    return obj
  end -- end function Snake:New(), or Snake class
  
  -- ************
  -- SPECIAL METHODS
  -- ************
  
  -- Remove and add any newly created cells to the pointTable
  -- then refresh the indices.
  function refreshPointTable()
    -- add snake's tail to okay list
    pointTable[pairToNum(ourSnake[1]:getX(), ourSnake[1]:getY())] = pairToNum(ourSnake[1]:getX(), ourSnake[1]:getY())
    -- mark other elements of snake as bad
    pointTable[pairToNum(ourSnake[#ourSnake]:getX(), ourSnake[#ourSnake]:getY())] = "NIL"
    -- refresh the index
    refreshIndices()
  end -- function refreshPointTable()
  
  -- check all values in pointTable, and assign
  -- an index to them. If the table runs out of indices,
  -- tell the user they won.
  function refreshIndices()
    indexIndex = 1
    for i, v in pairs(pointTable) do
      if v ~= "NIL" then
        indexTable[indexIndex] = v
        indexIndex = indexIndex + 1
      end
    end
    if indexIndex == 1 then 
      winStatement = "You win!" 
      state = "gameover" 
    end
  end
  
  -- hash a pair to a number
  function pairToNum(someX, someY)
    return ((someX - 1) * cellsTall ) + someY
  end
  
  -- unhash a number back into its coordinate points
  function numToPair(thisNum)
    local conX = 1 + math.floor((thisNum - 1)/cellsTall)
    local conY = 1 + ((thisNum - 1) % cellsTall)
    return conX, conY
  end
  
  -- First check if there is any space on the grid left.
  -- Otherwise create a random number based on the indexTable,
  -- hash it out to a pair, and make a new fruit based on 
  -- those pairs.
  function makeFruit()
    if indexSize == 0 then return end
    local ranNum = math.random(1,indexSize)
    fruit = Cell:New(numToPair(tonumber(indexTable[ranNum])))
    pointTable[pairToNum(fruit:getX(), fruit:getY())] = "NIL"
    indexSize = indexSize - 1
    refreshIndices()
    love.audio.play(arrowSound)
    speedUp()
    return fruit
  end
  
  -- Make sure the snake doesn't run into itself or the walls.
  function checkCollision()
    for i = 1, #ourSnake - 1 do
      if ourSnake[#ourSnake]:getHash() == ourSnake[i]:getHash() 
        or ourSnake[#ourSnake]:getX() < 1 
        or ourSnake[#ourSnake]:getX() > cellsWide
        or ourSnake[#ourSnake]:getY() < 1
        or ourSnake[#ourSnake]:getY() > cellsTall then
          state = "gameover"
      end
    end
  end
  
  function clearTables()
    pointTable = nil
    indexTable = nil
    pointTable = {}
    indexTable = {}
    ourSnake = nil
  end
  
  -- prime up the tables for the game.
  function fillTables()
    pointTable = {}
    indexTable = {}
    indexSize = 0
    for i = 1, cellsWide do 
      for j = 1, cellsTall do
        pointTable[pairToNum(i, j)] = pairToNum(i, j)
        table.insert(indexTable, pointTable[pairToNum(i, j)])
        indexSize = indexSize + 1
      end
    end
  end -- fillTables function

  -- make new snake and create its cells, then update its values
  -- in the pointTable.
  function makeASnake()
    ourSnake = Snake:New()
    for i = 4, 0, -1 do
      ourSnake:eat(Cell:New(snakeStartX,snakeStartY+i)) 
    end
    
    -- remove snake cells from list
    for i = 2, #ourSnake do
      pointTable[tonumber(pairToNum(tonumber(ourSnake[i]:getX()), tonumber(ourSnake[i]:getY())))] = "NIL"
      indexSize = indexSize - 1
    end  
    refreshIndices()
  end
  
  function speedUp()
    if indexSize % 5 == 0 then
      fps = fps + 1
    end
  end
  
  -- create all the necessary objects to start the game
  function startGame()
    clearTables()
    fillTables()
    points = -1
    makeASnake()
    fruit = makeFruit()
    head = headDown
    direction = "down"
  end
  
  function updateHighScore()
    if points > tonumber(highScore) then 
      highScore = points
      newScore = true
    end
  end
  
  -- currently broken
  function overWrite()
    --[[if newScore == true then
      saveFile:open("w")
      saveFile:write("" .. highScore .. "")
      saveFile:close()
    end]]--
  end  
  
  -- select how fast the game goes.
  function selectMode()
    callonce = true
    if arrowY == 159 then fps = 7
    elseif arrowY == 189 then fps = 12
    elseif arrowY == 219 then fps = 17 
    elseif arrowY == 249 then love.event.push("quit") end
  end
  
  state = "title"
  -- countdown to starting the game
  countdownNum = 4
  skipOnce = true
  gameWait = true
  -- what's displayed when the game is over
  winStatement = "Game over"
end -- end love.load()

-- *******************
-- UPDATE FUNCTION
--[[
Title state: await user's selection
Countdown state: countdown to the start of game
Game state: Check if snake has eaten a fruit; check key pressed,
move the snake, check collisions, and refresh the empty space table.
Game over state: similar to title state.
]]--
-- *******************

function love.update(dt)
  pressed = "false"
  if state == "title" then
    function love.keypressed(key)
      if key == " " or key == "return" then
        state = "countdown"
        selectMode()
        startGame()
      elseif key == "up" then
        if arrowY > 170 then 
          arrowY = arrowY - 30
          love.audio.play(arrowSound)
          end
      elseif key == "down" then
        if arrowY < 249 then 
          arrowY = arrowY + 30 
          love.audio.play(arrowSound)
          end
      end
    end
  
  elseif state == "countdown" then
    local startTime = love.timer.getTime()
    if countdownNum <= 1 then 
      state = "game"  
    end
    local endTime = love.timer.getTime()
    local totalTime = endTime - startTime
    if skipOnce == false and totalTime < 1 then
      love.timer.sleep(1 - totalTime)
    end
    countdownNum = countdownNum - 1
    love.audio.play(arrowSound)
    skipOnce = false
    
  elseif state == "game" then
    countdownNum = 4
    
    -- Check if fruit is same value as cells in snake
    -- If yes, add fruit to snake
    if fruit:isSameCell(ourSnake[#ourSnake]) then
      ourSnake:eat(fruit)
      refreshPointTable()
      fruit = makeFruit()
    end
    
    function love.keypressed(key) 
      if key == "up" and direction ~= "down" and pressed == "false" then
        direction = "up"
        head = headUp
        pressed = "true"
      elseif key == "down" and direction ~= "up" and pressed == "false" then
        direction = "down"
        head = headDown
        pressed = "true"
      elseif key == "left" and direction ~= "right" and pressed == "false" then
        direction = "left"
        head = headLeft
        pressed = "true"
      elseif key == "right" and direction ~= "left" and pressed == "false" then
        direction = "right"
        head = headRight
        pressed = "true"
      end -- end elseif clause
    end -- end keypressed event
    
    ourSnake:move(direction)
    checkCollision()
    refreshPointTable()
  
  elseif state == "gameover" then
    overWrite()
    skipOnce = true
    function love.keypressed(key)
      if key == " " or key == "return" then
        selectMode()
        startGame()
        state = "countdown"
        gamewait = true
      elseif key == "up" then
        if arrowY > 170 then 
          arrowY = arrowY - 30 
          love.audio.play(arrowSound)
          end
      elseif key == "down" then
        if arrowY < 249 then 
          arrowY = arrowY + 30 
          love.audio.play(arrowSound)
          end
      end
    end -- end function
  end -- end gameover state
end -- end update

--[[ ***************
DRAW FUNCTION
***************** ]]--
function love.draw()
  love.graphics.setColor(255, 255, 255, 255)
  love.graphics.draw(bg, 0, 0)
  
  if state == "title" then
    love.graphics.setFont(bigFont)
    love.graphics.setColor(50, 255, 200, 255)
    love.graphics.printf("Eternal", 0, actualHeight/8, actualWidth, "center")
    love.graphics.printf("Caterpillar", 0, actualHeight/ 4, actualWidth, "center")
    love.graphics.setFont(littleFont)
    love.graphics.setColor(155, 255, 215, 225)
    love.graphics.printf("Arrow keys move, space selects", 0, actualHeight/2.5, actualWidth, "center")
    love.graphics.setColor(200, 255, 205, 255)
    love.graphics.draw(arrow, arrowX, arrowY, 0, .75, .75)
    love.graphics.print("Slow", 100, 165)
    love.graphics.print("Less Slow", 100, 195)
    love.graphics.print("Not Slow", 100, 225)
    love.graphics.print("Quit", 100, 255)
    
  elseif state == "countdown" then
      love.graphics.print(countdownNum, actualWidth/2, actualHeight/2)
    
  elseif state == "game" then
    love.graphics.setColor(255,255,255,255)
    love.graphics.draw(fruitPic, (fruit:getX() - 1) * cellSize + 20, (fruit:getY() - 1) * cellSize + 20)
    for i = 2, #ourSnake - 1 do -- draw snake except at ghost cell and head.
      love.graphics.draw(cellPic, (ourSnake[i]:getX() - 1) * cellSize + 20, (ourSnake[i]:getY() - 1) * cellSize + 20)
    end
    love.graphics.draw(head, (ourSnake[#ourSnake]:getX() - 1) * cellSize + 20, (ourSnake[#ourSnake]:getY() - 1) * cellSize + 20) -- draw head
    love.graphics.setFont(littleFont)
    love.graphics.print(points, 3, 280)
    love.graphics.printf("High score: " .. highScore, 0, 280, actualWidth-3, "right")
    
  elseif state == "gameover" then
    love.graphics.setColor(50, 255, 200, 255)
    love.graphics.setFont(bigFont)
    love.graphics.printf(winStatement, 0, actualHeight/5, actualWidth, "center")
    love.graphics.setFont(littleFont)
    love.graphics.setColor(200, 255, 205, 255)
    love.graphics.printf("Press space to try again.", 0, actualHeight/3, actualWidth, "center")
    love.graphics.print("Slow", 100, 165)
    love.graphics.print("Less Slow", 100, 195)
    love.graphics.print("Not Slow", 100, 225)
    love.graphics.print("Quit", 100, 255)
    love.graphics.setColor(255, 255, 255, 255)
    love.graphics.draw(arrow, arrowX, arrowY, 0, .75, .75)
  end
  love.graphics.draw(border, 0, 0)
end

 -- EDITING THE LOVE.RUN FUNCTION
function love.run()
  fps = 10

    math.randomseed(socket.gettime()*10000)
    math.random() math.random()

    if love.load then love.load(arg) end

    local dt = 0

    -- Main loop time.
    while true do
      local frame_start_time = love.timer.getMicroTime() -- take time measurement from start time of the frame
        -- Process events.
        if love.event then
            love.event.pump()
            for e,a,b,c,d in love.event.poll() do
                if e == "quit" then
                    if not love.quit or not love.quit() then
                        if love.audio then
                            love.audio.stop()
                        end
                        return
                    end
                end
                love.handlers[e](a,b,c,d)
            end
        end

        -- Update dt, as we'll be passing it to update
        if love.timer then
            love.timer.step()
            dt = love.timer.getDelta()
        end

        -- Call update and draw
        if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled
        if love.graphics then
            love.graphics.clear()
            if love.draw then love.draw() end
        end

        if love.timer then love.timer.sleep(0.001) end
        if love.graphics then love.graphics.present() end

-- lowers framerate so double frames don't happen
        local frame_end_time = love.timer.getMicroTime()
        local frame_time = frame_end_time - frame_start_time
        if frame_time < 1/fps then
          love.timer.sleep(1/ fps - frame_time)
        end
        
    end

end
