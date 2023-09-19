def tick args
  # using sample 02_input_basics/07_managing_scenes as an initial sort of starting point/template
  # setup some handy ivars
  @args_state   = args.state
  @args_inputs  = args.inputs
  @args_outputs = args.outputs
  @args_gtk     = args.gtk

  current_scene = @args_state.current_scene

  case current_scene
  when :title_scene
    tick_title_scene
  when :game_scene
    tick_game_scene
  when :game_over_scene
    tick_game_over_scene
  else
    @args_state.current_scene ||= :title_scene
  end
  
  if @args_state.next_scene
    @args_state.current_scene = @args_state.next_scene
    @args_state.next_scene = nil
  end
end

def defaults
  @my_tick_count = 0   # sort of shadowing the tick count, may prove useful
  @scroll_point_at = 0 # used for positioning sections of the scrolling background
  @args_state.defaults_set = true
end

def tick_title_scene
  @args_outputs.labels << { x: 640,
                    y: 360,
                    text: "Title Scene (click to go to game)",
                    alignment_enum: 1 }

  if @args_inputs.mouse.click
    @args_state.next_scene = :game_scene
    defaults if @args_state.defaults_set.nil?
  end
end

def tick_game_scene
  @args_outputs.background_color = [0, 0, 0]
  
  render_background
  show_framerate

  if @args_inputs.mouse.click
    @args_state.next_scene = :game_over_scene
  end
end

def render_background
  # parallax inspiration from 99_genre_arcade/flappy_dragon sample
  # scroll_point_at   = state.scene_at if state.scene == :menu
  # scroll_point_at   = state.death_at if state.countdown > 0
  @scroll_point_at = @my_tick_count
  @my_tick_count += 1

  waves = []
  waves << scrolling_background(@scroll_point_at, 'sprites/water5.png', 0.25, 240)
  waves << scrolling_background(@scroll_point_at, 'sprites/water4.png', 0.5 , 182)
  waves << scrolling_background(@scroll_point_at, 'sprites/water3.png', 1.0 , 122)
  waves << scrolling_background(@scroll_point_at, 'sprites/water2.png', 2.0 , 60)
  # hax stick ship in here for now to get it in at the correct layer
  waves << {
           x:                   400,
           y:                   350,
           w:                   458,
           h:                   322,
           path: "sprites/ship.png",
           angle:                 0,
           a:                   255
           }
  waves << scrolling_background(@scroll_point_at, 'sprites/water1.png', 4.0 , 0)
  @args_outputs.sprites << waves
end

def scrolling_background at, path, rate, y = 0
  [
    { x:    0 - at.*(rate) % 1280, y: y, w: 1280, h: 720, path: path },
    { x: 1280 - at.*(rate) % 1280, y: y, w: 1280, h: 720, path: path }
  ]
end

def show_framerate
  # @variable s are called instance variables in ruby.
  # Which means you can access these variables in ANY METHOD inside the class.
  # [ Across all methods in the class]
  @show_fps = !@show_fps if @args_inputs.keyboard.key_down.forward_slash
  #@args_outputs.labels << { x: 20,
  #                  y: 610,
  #                  r: 255,
  #                  g: 255,
  #                  b: 255,
  #                  size_enum: -2,
  #                  text: "FPS: #{@args_gtk.current_framerate.to_sf}" } if @show_fps
  @args_outputs.primitives << @args_gtk.current_framerate_primitives if @show_fps
end

def tick_game_over_scene
  @args_outputs.labels << { x: 640,
                    y: 360,
                    text: "Game Over Scene (click to go to title)",
                    alignment_enum: 1 }

  if @args_inputs.mouse.click
    @args_state.next_scene = :title_scene
    @args_state.defaults_set = nil
  end
end
