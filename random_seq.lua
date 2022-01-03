-- random probability seq
--
-- key 2: pause / resume
-- enc 2: bias note a/b
-- enc 3: trigger probability
--
-- crow output 1: trig a
-- crow output 2: 1v/oct note a
-- crow output 3: trig b
-- crow output 4: 1v/oct note b


MusicUtil = require("musicutil")
engine.name = "PolyPerc"

options_a = {}
options_a.OUTPUT = {"audio", "crow out 1+2", "crow out 3+4", "crow ii JF"}
options_b = {}
options_b.OUTPUT = {"audio", "crow out 1+2", "crow out 3+4", "crow ii JF"}

-- we can extract a list of scale names from musicutil using the following
scale_names = {}
for i = 1, #MusicUtil.SCALES do
  table.insert(scale_names, MusicUtil.SCALES[i].name)
end

playing = false -- whether notes are playing
prob = 50
prob_skip = 50
prob_skip_rev = 50 -- my hacky way of reversing the indicator
playing_note_a = true
skipping_note = false
current_note_name = ''

function init()
  engine.release(2)
  screen.font_face(10)
  crow.output[1].action = 'pulse(0.02,5)'
  crow.output[3].action = 'pulse(0.02,5)'

  -- setting root notes using params
  params:add{type = "number", id = "root_note", name = "root note",
    min = 0, max = 127, default = 60, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
    action = function() build_scale() end} -- by employing build_scale() here, we update the scale

  -- setting scale type using params
  params:add{type = "option", id = "scale", name = "scale",
    options = scale_names, default = 5,
    action = function() build_scale() end} -- by employing build_scale() here, we update the scale

  -- setting how many notes from the scale can be played
  params:add{type = "number", id = "pool_size", name = "note pool size",
    min = 1, max = 32, default = 12,
    action = function() build_scale() end}

  -- setting output options
  params:add{type = "option", id = "output_a", name = "output a",
    options = options_a.OUTPUT, default = 1}
  params:add{type = "option", id = "output_b", name = "output b",
    options = options_b.OUTPUT, default = 1}

  build_scale() -- builds initial scale
  play = clock.run(play_notes) -- starts the clock coroutine which plays a random note from the scale
  playing = true
end

function build_scale()
  notes_nums = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale"), params:get("pool_size")) -- builds scale
  notes_freq = MusicUtil.note_nums_to_freqs(notes_nums) -- converts note numbers to an array of frequencies
end

function play_notes()
  while true do
    clock.sync(1/2)
    local rnd = math.random(1,#notes_nums) -- a random integer
    current_note_num = notes_nums[rnd] -- select a random note from the scale
    current_note_name = MusicUtil.note_num_to_name(current_note_num,true) -- convert note number to name

    local note_a = notes_freq[rnd]
    local note_b = notes_freq[rnd]/2 -- transposing note down an octave
    local crow_note_a = (current_note_num-60)/12
    local crow_note_b = (current_note_num-60)/12

    local randSkipProb = math.floor(math.random() * 100) -- Random probability
    local randProb = math.floor(math.random() * 100) -- Random probability

    if prob_skip > randSkipProb then -- play a note
      skipping_note = false
      if prob < randProb then
        -- PLAY NOTE 1
        if params:get('output_a') == 1 then -- Norns audio
          engine.release(0.2)
          engine.hz(note_a)
        end

        if params:get('output_a') == 2 then
          crow.output[2].volts = crow_note_a -- crow 1+2
          crow.output[1].execute()
        end

        if params:get('output_a') == 3 then
          crow.output[4].volts = crow_note_a -- crow 3+4
          crow.output[3].execute()
        end

        if params:get('output_a') == 4 then
          crow.ii.jf.play_note(crow_note_a, 5)
        end

        playing_note_a = true
      else
      -- PLAY NOTE 2
        if params:get('output_b') == 1 then -- Norns audio
          engine.release(1.5)
          engine.hz(note_b)
        end

        if params:get('output_b') == 2 then
          crow.output[2].volts = crow_note_b -- crow 1+2
          crow.output[1].execute()
        end

        if params:get('output_b') == 3 then
          crow.output[4].volts = crow_note_b -- crow 3+4
          crow.output[3].execute()
        end

        if params:get('output_b') == 4 then
          crow.ii.jf.play_note(crow_note_b, 5)
        end
        playing_note_a = false
      end
    else
      skipping_note = true
    end
    redraw()
  end
end

function stop_play() -- stops the coroutine playing the notes
  clock.cancel(play)
  playing = false
  redraw()
end

function enc(n,d) -- Encoder probability
  -- encoder 1 (prob)
  if  n == 2 then
    prob = prob + d
    if prob > 100 then prob = 100 end
    if prob < 0 then prob = 0 end
    redraw()
  elseif n == 3 then
    prob_skip = prob_skip + d
    prob_skip_rev = prob_skip_rev - d
    if prob_skip > 100 then prob_skip = 100 end
    if prob_skip < 0 then prob_skip = 0 end
    if prob_skip_rev > 100 then prob_skip_rev = 100 end
    if prob_skip_rev < 0 then prob_skip_rev = 0 end
    redraw()
  end
end

function key(n,z)
  if n == 2 and z == 1 then
    if not playing then
      play = clock.run(play_notes) -- starts the clock coroutine which plays a random note from the scale
      playing = true
    elseif playing then
      stop_play()
    end
  end
end

function draw_note()
  if skipping_note == true then
    current_note_name = '__'
  end
  if playing_note_a == true then
    screen.font_face(10)
    screen.font_size(24)
    screen.move(15,37)
    screen.text(current_note_name) -- display the name of the note that is playing
  else
    screen.font_face(10)
    screen.font_size(24)
    screen.move(115,37)
    screen.text_right(current_note_name) -- display the name of the note that is playing
  end
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(64,32)

  if params:get('output_a') == 4 or params:get('output_b') == 4 then
    crow.ii.jf.mode(1)
  else
    crow.ii.jf.mode(0)
  end

  if playing == true then
    draw_note()

    -- prob indicator left range
    screen.rect (0, 3, 3, 1)
    screen.level(2)
    screen.fill()
    screen.close()

    -- prob indicator middle range
    screen.rect (63, 3, 1, 1)
    screen.level(2)
    screen.fill()
    screen.close()

    -- prob indicator right range
    screen.rect (125, 2, 1, 3)
    screen.level(2)
    screen.fill()
    screen.close()

    -- prob indicator
    screen.rect (prob * 1.24 + 1, 1, 1, 5)
    screen.level(2)
    if prob == 0 then screen.level(15) end
    if prob == 50 then screen.level(15) end
    if prob == 100 then screen.level(15) end
    screen.fill()
    screen.close()

    -- trig prob indicator top range
    screen.rect (124, 3, 3, 1)
    screen.level(2)
    screen.fill()
    screen.close()

    -- trig prob indicator middle range
    screen.rect (125, 32, 1, 1)
    screen.level(2)
    screen.fill()
    screen.close()

    -- trig prob indicator bottom range
    screen.rect (124, 61, 3, 1)
    screen.level(2)
    screen.fill()
    screen.close()

    -- trig prob indicator
    screen.rect (123, prob_skip_rev * .58 + 3, 5, 1)
    screen.level(2)
    if prob_skip_rev == 50 then screen.level(15) end
    if prob_skip_rev == 0 then screen.level(15) end
    if prob_skip_rev == 100 then screen.level(15) end
    screen.fill()
    screen.close()
  else
    screen.move(62,34)
    screen.font_size(14)
    screen.text_center("K2 to resume")
  end

  screen.update()
end