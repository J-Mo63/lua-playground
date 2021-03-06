-- A module for player and player controller related methods and variables
local M = {}

-- Module constants
local PLAYER_SPEED = 0.2
local PLAYER_SCALE = 0.15
local ANIMAION_SPEED = 10
local INTERACTION_OFFSET = 5

-- The player location
M.transform = {
  x, y,
  w, h,
}

-- A list of collidable object transforms in the map
M.collidable_objects = {}
M.tagged_objects = {}

-- The control overrride module field
M.control_override = false

-- The player sprites
local sprites = {
  walking_down = {},
  walking_up = {},
  walking_right = {},
  walking_left = {},
}

-- Other module fields
local is_idle = true
local current_animation = nil
local current_frame = 0
local frame_tick = 0
local available_action = nil
local action_cooldown = 0
local scaled_player_scale = nil
local scaled_player_speed = nil

-- Initialises the player module for use
function M.init()
  -- Import walking down animation
  table.insert(sprites.walking_down, 
    love.graphics.newImage("assets/char/player-idle-down.png"))
  table.insert(sprites.walking_down, 
    love.graphics.newImage("assets/char/player-walking-down-1.png"))
  table.insert(sprites.walking_down, 
    love.graphics.newImage("assets/char/player-idle-down.png"))
  table.insert(sprites.walking_down, 
    love.graphics.newImage("assets/char/player-walking-down-2.png"))

  -- Import walking up animation
  table.insert(sprites.walking_up, 
    love.graphics.newImage("assets/char/player-idle-up.png"))
  table.insert(sprites.walking_up, 
    love.graphics.newImage("assets/char/player-walking-up-1.png"))
  table.insert(sprites.walking_up, 
    love.graphics.newImage("assets/char/player-idle-up.png"))
  table.insert(sprites.walking_up, 
    love.graphics.newImage("assets/char/player-walking-up-2.png"))

  -- Import walking right animation
  table.insert(sprites.walking_right, 
    love.graphics.newImage("assets/char/player-idle-right.png"))
  table.insert(sprites.walking_right, 
    love.graphics.newImage("assets/char/player-walking-right-1.png"))
  table.insert(sprites.walking_right, 
    love.graphics.newImage("assets/char/player-idle-right.png"))
  table.insert(sprites.walking_right, 
    love.graphics.newImage("assets/char/player-walking-right-2.png"))

  -- Import walking left animation
  table.insert(sprites.walking_left, 
    love.graphics.newImage("assets/char/player-idle-left.png"))
  table.insert(sprites.walking_left, 
    love.graphics.newImage("assets/char/player-walking-left-1.png"))
  table.insert(sprites.walking_left, 
    love.graphics.newImage("assets/char/player-idle-left.png"))
  table.insert(sprites.walking_left, 
    love.graphics.newImage("assets/char/player-walking-left-2.png"))

  -- Set the default animation
  current_animation = sprites.walking_down

  -- Setup player parameters
  M.setup_player()
end

-- Updates the player module parameters
function M.setup_player()
  -- Get scaled player values
  scaled_player_scale = PLAYER_SCALE * Module.map.map_config.tile_scale
  scaled_player_speed = PLAYER_SPEED * Module.map.map_config.tile_scale

  -- Set player starting location and size
  M.transform.w = current_animation[1]:getWidth() * scaled_player_scale
  M.transform.h = M.transform.w
end

-- Updates the player and input state
function M.update(dt)
  if not M.control_override then
    -- Get movement profiles for input
    local temp_x = 0
    local temp_y = 0
    if love.keyboard.isDown("right") then
      temp_x = (dt * 100)
      current_animation = sprites.walking_right
    end
    if love.keyboard.isDown("left") then
      temp_x = -(dt * 100)
      current_animation = sprites.walking_left
    end
    if love.keyboard.isDown("down") then
      temp_y = (dt * 100)
      current_animation = sprites.walking_down
    end
    if love.keyboard.isDown("up") then
      temp_y = -(dt * 100)
      current_animation = sprites.walking_up
    end

    -- Normalise player's movement
    local magnitude = math.sqrt(temp_x^2 + temp_y^2)
    if magnitude > 1 then
      temp_x = M.transform.x + (temp_x / magnitude) * scaled_player_speed
      temp_y = M.transform.y + (temp_y / magnitude) * scaled_player_speed

      -- Check if the player collided with any collidable objects
      local player_object = {temp_x, temp_y, M.transform.w, M.transform.h}
      if M.items_collided(player_object, M.collidable_objects) then
        -- Check if either x or y was would work on their own
        player_object = {temp_x, M.transform.y, M.transform.w, M.transform.h}
        if M.items_collided(player_object, M.collidable_objects) then
          player_object = {M.transform.x, temp_y, M.transform.w, M.transform.h}
          if not M.items_collided(player_object, M.collidable_objects) then
            M.transform.y = temp_y
          end
        else
          M.transform.x = temp_x
        end
      else
        -- Set the movements to the transform if it didn't collide
        M.transform.x = temp_x
        M.transform.y = temp_y
      end
      is_idle = false
    else
      -- Set the player as idle
      is_idle = true
    end

    -- Check if the player collided with any tagged objects
    available_action = M.items_collided(
                    {M.transform.x - INTERACTION_OFFSET, 
                     M.transform.y - INTERACTION_OFFSET, 
                     M.transform.w + INTERACTION_OFFSET*2, 
                     M.transform.h + INTERACTION_OFFSET*2}, 
                     M.tagged_objects, true)

    -- Deincrement the action cooldown
    if action_cooldown > 0 then
      action_cooldown = action_cooldown - 1
    end

    -- Calculate the current frame tick
    if frame_tick >= ANIMAION_SPEED then
      current_frame = current_frame + 1
      frame_tick = 0
    end
    frame_tick = frame_tick + 1
  end
end

function M.use()
  -- Allow player to activate action items
  if available_action and action_cooldown <= 0 then
    Module.action.dispatch_action(available_action)
    action_cooldown = 50
  end
end

-- Renders the player sprite to the screen
function M.render()
  -- Check whether the player is idle
  local frame_num = 1
  if not is_idle then
    -- Get the current frame for the animation
    frame_num = math.fmod(current_frame, table.getn(current_animation)) + 1
  end

  -- Draw the current player sprite animation to the screen
  love.graphics.draw(current_animation[frame_num], M.transform.x, M.transform.y, 0, scaled_player_scale)
  if available_action and action_cooldown <= 0 then
    local text = "Press f"
    local font = love.graphics.getFont()
    local width = M.transform.x - (font:getWidth(text) / 2) + M.transform.w / 2
    love.graphics.print(text, width, M.transform.y + M.transform.h + 10)
  end

  -- Draw player hitbox to the screen
  if Module.system.debug_mode then
    love.graphics.setColor(255,0,0)
    love.graphics.rectangle("line", M.transform.x, M.transform.y, M.transform.w, M.transform.h)
    love.graphics.setColor(255,255,255)
  end
end

-- A method to check if the player collides with any of a set of items
function M.items_collided(player, items, return_val)
  -- Check if the player collided with any items
  for i, item in ipairs(items) do
    -- Set the required return values
    local positive_val = true
    local negative_val = false
    if return_val then
      positive_val = item[5]
      negative_val = nil
    end
    -- Check item collision
    if M.collided(player, item) then
      return positive_val
    end
  end
  return negative_val
end

-- A method to check whether two objects collide
function M.collided(object_a, object_b)
  return object_a[1] < object_b[1] + object_b[3] and
         object_b[1] < object_a[1] + object_a[3] and
         object_a[2] < object_b[2] + object_b[4] and
         object_b[2] < object_a[2] + object_a[4]
end

-- A method to set the centred position of the player
function M.set_position(positions)
  M.transform.x = positions.x - M.transform.w / 2
  M.transform.y = positions.y - M.transform.h / 2
end
 
return M