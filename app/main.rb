$gtk.reset
$gtk.set_window_scale(0.75)
# $gtk.disable_console if $gtk.production?

def tick args
  # using sample 02_input_basics/07_managing_scenes as an initial sort of starting point/template
  @args_state    = args.state
  @args_inputs   = args.inputs
  @args_outputs  = args.outputs
  @args_easing   = args.easing
  @args_geometry = args.geometry
  @args_gtk      = args.gtk

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

def tick_game_over_scene
  render_background_waves
  render_pirate_ship_fg_wave
  draw_fish
  move_anchors_and_chains_outward
  move_anchors_and_chains_inward
  draw_anchors_and_chains
  @args_outputs.labels << { x: 640,
                            y: 360,
                            text: "Game Over Scene (click to go to title)",
                            alignment_enum: 1 }
  output_to_sprites

  if @args_inputs.mouse.click
    @args_state.next_scene = :title_scene
    @args_state.defaults_set = nil
  end
end

def tick_game_scene
  bump_timer
  render_background_waves
  render_pirate_ship_fg_wave
  update_all_anchor_ship_position
  check_anchor_input unless @game_paused
  draw_fish
  move_fish
  move_anchors_and_chains_outward
  check_anchors_endpoint
  move_anchors_and_chains_inward
  swing_anchor_back_to_idle
  draw_anchors_and_chains
  replenish_fish
  output_to_sprites
  show_framerate

  #@args_outputs.labels << { x: 640,
  #                          y: 360,
  #                          text: "#{@args_gtk.current_framerate_render} fps render, #{@args_gtk.current_framerate_calc} fps simulation",
  #                          size_enum: 20,
  #                          r: 255,
  #                          g: 0,
  #                          b: 0,
  #                          alignment_enum: 1,
  #                          vertical_alignment_enum: 1 }

  if @args_inputs.keyboard.key_down.forward_slash # @args_inputs.mouse.button_right # mouse.click
    # for now, the top part of the screen ends the game scene
    @args_state.next_scene = :game_over_scene # if @args_inputs.mouse.click.point.y > 400
  end
end

def bump_timer
  # add check here whether the game has focus or not
  # if not, pause music, skip increment count, etc
  if !@args_inputs.keyboard.has_focus && @args_state.tick_count != 0
    @game_paused = true
    @args_outputs.labels << { x: 640,
                              y: 360,
                              text: "Game Paused",
                              alignment_enum: 1 }
  else
    @scroll_point_at = @my_tick_count
    @my_tick_count += 1 # unless @show_fps
    @game_paused = nil
  end
end

def move_single_fish fish
  # multiple sprites inspiration from 03_rendering_sprites/01_animation_using_separate_pngs sample
  fish.path = "sprites/fishGrayscale_#{fish.l.frame_index 2, 20, true, @my_tick_count}.png"
  fish.x += fish[:s] unless @game_paused
  fish.y = fish.y + (2 * rand + 2).*(0.25).randomize(:ratio, :sign) unless @game_paused
  fish.y = fish.y.cap_min_max(-12, 288)
  #@waves << { x: fish.x,
  #            y: fish.y,
  #            w: fish.w * 0.8,
  #            h: fish.h * 0.8,
  #            path: "sprites/circle-white.png", # path: :pixel,
  #            anchor_x: -0.1,
  #            anchor_y: -0.1,
  #            a: 25,
  #            r: 255,
  #            g: 255,
  #            b: 255 }
  if fish[:s] > 0
    if fish.x > 1280
      fish.x = (1280.randomize :ratio) * -1
      fish.y = (300.randomize :ratio) - 12
      fish[:s] = 1 + (4.randomize :ratio)
    end
  else
    if fish.x < -128
      fish.x = (1280.randomize :ratio) + 1280
      fish.y = (300.randomize :ratio) - 12
      fish[:s] = (1 + (4.randomize :ratio)) * -1
    end
  end
  # debug rough collision area
  # @args_outputs.borders << [fish.x, fish.y, fish.w, fish.h]
  # @args_outputs.borders << [fish.x + (fish.w/2),
  #                           fish.y + (fish.h/2),
  #                           2,
  #                           2]
end

def draw_fish
  @waves << @fish
end

def move_fish
  # @fish.each { |f| move_single_fish f } # unless @show_fps
  # Fn.each(@fish) { |f| move_single_fish f }
  # levi performance tricks
  a = @fish
  l = a.length
  i = 0
  while i < l
    move_single_fish(a[i])
    i += 1
  end
end

def check_anchor_input
  # if there is player input, then check for nearest available anchor
  if @args_inputs.mouse.click
    mouse_x = @args_inputs.mouse.click.point.x
    mouse_y = @args_inputs.mouse.click.point.y
    mouse_x = mouse_x.cap_min_max(0, 1280)
    mouse_y = mouse_y.cap_min_max(0, 720)
    # unless mouse_y > 340 # check in the main body of the front most wave, subject to change
      idle_anchors = @anchors.select { |_, anchor| anchor[:state] == :idle }
      unless idle_anchors.empty?
        distances = idle_anchors.map do |id, obj|
          # distance = Math.sqrt((mouse_x - obj[:ship.x])**2 + (mouse_y - obj[:ship.y])**2 )
          # two styles of accessing the information shown here
          distance = (mouse_x - obj.ship.x)**2 + (mouse_y - obj[:ship][:y])**2
          { id: id, distance: distance }
        end
        closest = distances.min_by { |item| item[:distance] }
        @anchors[closest.id].state = :outward
        @anchors[closest.id].target.x = mouse_x # assumes end size of 140
        @anchors[closest.id].target.y = mouse_y # assumes end size of 140
        @anchors[closest.id].duration = (Math.sqrt closest.distance ) / 7
        @anchors[closest.id].duration = @anchors[closest.id].duration.cap_min_max(25, 55)
        @anchors[closest.id].start = @my_tick_count
        # putz "distance: #{@anchors[closest.id].duration}"
      end
    # end
  end
end

def update_all_anchor_ship_position
  shangle = @position[@x_coor][:angle] * @convert
  shipy = @position[@x_coor][:y] + @water_level
  anchors = @anchors.map do |id, obj|
    if id == :left
      obj.ship.x = (419.5 + (458/2)) - (@radius1 * Math.sin(@dangle1 - shangle))
      obj.ship.y = (871 - shipy) - (@radius1 * Math.cos(@dangle1 - shangle))
    end
    if id == :middle
      obj.ship.x = (419.5 + (458/2)) - (@radius2 * Math.sin(@dangle2 - shangle))
      obj.ship.y = (871 - shipy) - (@radius2 * Math.cos(@dangle2 - shangle))
    end
    if id == :right
      obj.ship.x = (419.5 + (458/2)) + (@radius3 * Math.cos(@dangle3 - shangle))
      obj.ship.y = (871 - shipy) - (@radius3 * Math.sin(@dangle3 - shangle))
    end
  end
end

def move_anchors_and_chains_outward
  outward_anchors = @anchors.select { |_, anchor| anchor[:state] == :outward }
  unless outward_anchors.empty?
    outward_anchors.each_value do |anchor|
      sx = anchor.ship.x
      sy = anchor.ship.y
      tx = anchor.target.x
      ty = anchor.target.y
      progress = @args_easing.ease(anchor.start, @my_tick_count, anchor.duration, :smooth_stop_quad)
      calc_x = sx + (tx - sx) * progress
      calc_y = sy + (ty - sy) * progress
      calc_w = 70 + (140 - 70) * progress
      calc_h = 70 + (140 - 70) * progress
      calc_a = @args_geometry.angle_from anchor.ship, anchor.target
      # putz "angle: #{calc_a - 90}"
      distance = @args_geometry.distance anchor.ship, { x: calc_x, y: calc_y }
      distance = 910 if distance > 910
      @waves << { # where to render the render target
                  x: calc_x,
                  y: calc_y,
                  w: 70,
                  h: distance,
                  path: "sprites/chains.png",
                  angle: calc_a - 90,
                  anchor_x: 0.5,
                  anchor_y: 0,
                  angle_anchor_x: 0.5,
                  angle_anchor_y: 0,
                  source_x: 0,
                  source_y: 0,
                  source_w: 70,
                  source_h: distance, }
      @waves << { x: calc_x,
                  y: calc_y,
                  w: calc_w,
                  h: calc_h,
                  path: "sprites/anchor.png",
                  angle: calc_a - 90,
                  anchor_x: 0.5,
                  anchor_y: 1,
                  angle_anchor_x: 0.5,
                  angle_anchor_y: 1.0 }
      anchor.state = :endpoint if progress >= 1
    end
  end
end

def check_anchors_endpoint
  endpoint_anchors = @anchors.select { |_, anchor| anchor[:state] == :endpoint }
  unless endpoint_anchors.empty?
    endpoint_anchors.each_value do |anchor|
      anchor.start = @my_tick_count
      anchor.state = :inward
    end
  end
end

def move_anchors_and_chains_inward
  inward_anchors = @anchors.select { |_, anchor| anchor[:state] == :inward }
  unless inward_anchors.empty?
    inward_anchors.each do |id, anchor|
      sx = anchor.target.x
      sy = anchor.target.y
      tx = anchor.ship.x
      ty = anchor.ship.y
      progress = @args_easing.ease(anchor.start, @my_tick_count, anchor.duration, :identity)
      calc_x = sx + (tx - sx) * progress
      calc_y = sy + (ty - sy) * progress
      calc_w = 140 + (70 - 140) * progress
      calc_h = 140 + (70 - 140) * progress
      calc_a = @args_geometry.angle_from anchor.ship, anchor.target
      center_x = calc_x + (calc_w / 1.9) * Math.cos((calc_a - 180) * @convert)
      center_y = calc_y + (calc_h / 1.9) * Math.sin((calc_a - 180) * @convert)
      anchor.angle = calc_a - 90
      distance = @args_geometry.distance anchor.ship, { x: calc_x, y: calc_y }
      distance = 910 if distance > 910
      @waves << {
                  x: calc_x,
                  y: calc_y,
                  w: 70,
                  h: distance,
                  path: "sprites/chains.png",
                  angle: anchor.angle,
                  anchor_x: 0.5,
                  anchor_y: 0,
                  angle_anchor_x: 0.5,
                  angle_anchor_y: 0,
                  source_x: 0,
                  source_y: 0,
                  source_w: 70,
                  source_h: distance, }
      # draw the clump of fish
      if anchor.clump.length != 0
        c = anchor.clump 
        l = c.length
        i = 0
        while i < l
          c[i][:x] = center_x # + c[i][:x]
          c[i][:y] = center_y # + c[i][:y] 
          i += 1
        end
        # anchor.clump = []
        @waves << anchor.clump
      end

      @waves << { x: calc_x,
                  y: calc_y,
                  w: calc_w,
                  h: calc_h,
                  path: "sprites/anchor.png",
                  angle: anchor.angle,
                  anchor_x: 0.5,
                  anchor_y: 1,
                  angle_anchor_x: 0.5,
                  angle_anchor_y: 1.0 }
      # center_x = calc_x + (calc_w / 1.9) * Math.cos((calc_a - 180) * @convert)
      # center_y = calc_y + (calc_h / 1.9) * Math.sin((calc_a - 180) * @convert)
      
      # corner_x = center_x - (calc_w / 2)
      # corner_y = center_y - (calc_h / 2)
      # @args_outputs.borders << [ corner_x, corner_y, calc_w, calc_h ]

      anc = { x: center_x - (calc_w / 2), y: center_y - (calc_h / 2), w: calc_w, h: calc_h }
      collisions = @args_state.geometry.find_all_intersect_rect anc, @fish
      # @fish = @fish - collisions if collisions.length != 0
      # putz "collisions: #{collisions}"
      f = collisions
      l = f.length 
      if l != 0
        # putz "collision length: #{l}"
        i = 0
        while i < l
          fp = { x: f[i][:x] + (f[i][:w]/2), y: f[i][:y] + (f[i][:h]/2)}
          distance = @args_geometry.distance fp, { x: center_x, y: center_y }
          if distance < ((calc_w/2) + (f[i][:w]/2)) / 1.6
            @fish = @fish - [f[i]]
            # f[i][:x] = (center_x - f[i][:x]) / 2
            # f[i][:y] = (center_y - f[i][:y]) / 2
            f[i][:x] = center_x
            f[i][:y] = center_y
            f[i][:anchor_x] = 0.5
            f[i][:anchor_y] = 0.5
            # add this fish to the group of clumped fish on this anchor
            anchor.clump += [f[i]]
            # puts "clump len: #{anchor.clump.length}"
            # can adjust this later, maybe per fish weight score
            @water_level += 0.1 if @water_level < 16
            # putz "distance: #{distance}"
          end
          i += 1
        end
      end

      # @waves << { x: center_x,
      #             y: center_y,
      #             w: calc_w * 0.8, # w: 2,
      #             h: calc_h * 0.8, # h: 2,
      #             path: "sprites/circle-white.png", # path: :pixel,
      #             anchor_x: 0.5,
      #             anchor_y: 0.5,
      #             a: 25,
      #             r: 25,
      #             g: 25,
      #             b: 25 }
      anchor.state = :swing if progress >= 1
    end
  end
end

def swing_anchor_back_to_idle
  swing_anchors = @anchors.select { |_, anchor| anchor[:state] == :swing }
  unless swing_anchors.empty?
    anchors = swing_anchors.map do |id, obj|
      if id == :left and obj[:state] == :swing
        @waves << { x: @anchors.left.ship.x,
                    y: @anchors.left.ship.y,
                    w: 70,
                    h: 70,
                    path: "sprites/anchor.png",
                    anchor_x: 0.5,
                    anchor_y: 1,
                    angle_anchor_x: 0.5,
                    angle_anchor_y: 1.0,
                    angle: obj.angle }
      end
      if id == :middle and obj[:state] == :swing
        @waves << { x: @anchors.middle.ship.x,
                    y: @anchors.middle.ship.y,
                    w: 70,
                    h: 70,
                    path: "sprites/anchor.png",
                    anchor_x: 0.5,
                    anchor_y: 1.0,
                    angle_anchor_x: 0.5,
                    angle_anchor_y: 1.0,
                    angle: obj.angle }
      end
      if id == :right and obj[:state] == :swing
        @waves << { x: @anchors.right.ship.x,
                    y: @anchors.right.ship.y,
                    w: 70,
                    h: 70,
                    path: "sprites/anchor.png",
                    anchor_x: 0.5,
                    anchor_y: 1.0,
                    angle_anchor_x: 0.5,
                    angle_anchor_y: 1.0,
                    angle: obj.angle }
      end
      # putz "angle: #{obj.angle}"
      if obj.angle > 180
        obj.angle += 20
        obj.angle = 0 if obj.angle > 360
      elsif obj.angle < 0
        obj.angle += 20
        obj.angle = 0 if obj.angle > 0
      else
        obj.angle -=20
        obj.angle = 0 if obj.angle < 1
      end
      obj.state = :idle if obj.angle == 0 # && obj.clump.length == 0
      obj.clump = [] if obj.angle == 0
    end
  end
end

def render_background_waves
  @args_outputs.background_color = [0, 0, 0]
  # parallax inspiration from 99_genre_arcade/flappy_dragon sample
  @waves = []
  @x_coor = x_coor(@scroll_point_at, @wave_speed)
  @waves << scrolling_background(@x_coor, "sprites/water5.png", 240)
  @x_coor = x_coor(@scroll_point_at, @wave_speed * 2)
  @waves << scrolling_background(@x_coor, "sprites/water4.png", 182)
  @x_coor = x_coor(@scroll_point_at, @wave_speed * 4)
  @waves << scrolling_background(@x_coor, "sprites/water3.png", 122)
  @x_coor = x_coor(@scroll_point_at, @wave_speed * 8)
  @waves << scrolling_background(@x_coor, "sprites/water2.png", 60)
  @x_coor = x_coor(@scroll_point_at, @wave_speed * 16)
end

def render_pirate_ship_fg_wave
  # hax stick ship in here for now to get it in at the correct layer
  @waves << { x: 420,
              y: 708 - @position[@x_coor][:y] - @water_level,
              w: 458,
              h: 322,
              path: "sprites/ship_1.png",
              angle: ((@position[@x_coor][:angle])),
              a: 255 }
  # draw fish piling up here
  @waves << { x: 420,
              y: 708 - @position[@x_coor][:y] - @water_level,
              w: 458,
              h: 322,
              path: "sprites/ship_0.png",
              angle: ((@position[@x_coor][:angle])),
              a: 255 }
  @waves << scrolling_background(@x_coor, "sprites/water1.png")
end

def draw_anchors_and_chains
  idle_anchors = @anchors.select { |_, anchor| anchor[:state] == :idle }
  unless idle_anchors.empty?
    anchors = idle_anchors.map do |id, obj|
      if id == :left and obj[:state] == :idle
        @waves << { x: @anchors.left.ship.x,
                    y: @anchors.left.ship.y,
                    w: 70,
                    h: 70,
                    path: "sprites/anchor.png",
                    anchor_x: 0.5,
                    anchor_y: 1,
                    angle_anchor_x: 0.5,
                    angle_anchor_y: 1.0,
                    angle: 0 }
      end
      if id == :middle and obj[:state] == :idle
        @waves << { x: @anchors.middle.ship.x,
                    y: @anchors.middle.ship.y,
                    w: 70,
                    h: 70,
                    path: "sprites/anchor.png",
                    anchor_x: 0.5,
                    anchor_y: 1.0,
                    angle_anchor_x: 0.5,
                    angle_anchor_y: 1.0,
                    angle: 0 }
      end
      if id == :right and obj[:state] == :idle
        @waves << { x: @anchors.right.ship.x,
                    y: @anchors.right.ship.y,
                    w: 70,
                    h: 70,
                    path: "sprites/anchor.png",
                    anchor_x: 0.5,
                    anchor_y: 1.0,
                    angle_anchor_x: 0.5,
                    angle_anchor_y: 1.0,
                    angle: 0 }
      end
    end
  end
end

def replenish_fish
  @fish = @fish + [new_fish] if @fish.length < 100
end

def output_to_sprites
  @args_outputs.sprites << @waves
end

def x_coor at, rate
  (1280 - at.*(rate) % 1280).to_i
end

def scrolling_background x, path, y = 0
  [
    { x: x - 1280, y: y, w: 1280, h: 720, path: path },
    { x: x, y: y, w: 1280, h: 720, path: path }
  ]
end

def show_framerate
  # @variables are called instance variables in ruby.
  # Which means you can access these variables in ANY METHOD inside the class.
  # (Across all methods in the class - in this case, the top most class)
  @show_fps = !@show_fps if @args_inputs.keyboard.key_down.f # orward_slash
  @args_outputs.primitives << @args_gtk.framerate_diagnostics_primitives if @show_fps
  # @my_tick_count -= 1 if @show_fps # hack to test freezing the game
end

def new_fish
  fish_size = @fish_sizes_weighted.sample
  fish_color = @fish_colors_weighted.sample
  if rand < 0.5
    {
      x: (1280.randomize :ratio) * -1,
      y: (300.randomize :ratio) - 12,
      w: fish_size.w,
      h: fish_size.h,
      path: "sprites/fishGrayscale_0.png",
      s: 1 + (4.randomize :ratio),
      l: @my_tick_count,
      c: @fish_colors_weighted.sample,
      flip_horizontally: true,
      a: 255,
      r: fish_color.r,
      g: fish_color.g,
      b: fish_color.b,
      anchor_x: 0,
      anchor_y: 0
    }
  else
    {
      x: (1280.randomize :ratio) + 1280,
      y: (300.randomize :ratio) - 12,
      w: fish_size.w,
      h: fish_size.h,
      path: "sprites/fish#{@fish_colors_weighted.sample}_0.png",
      s: (1 + (4.randomize :ratio)) * -1,
      l: @my_tick_count,
      c: @fish_colors_weighted.sample,
      flip_horizontally: false,
      a: 255,
      r: fish_color.r,
      g: fish_color.g,
      b: fish_color.b
    }
  end
end

def defaults
  @my_tick_count = 0   # sort of shadowing the tick count, may prove useful
  @scroll_point_at = 0 # used for positioning sections of the scrolling background
  @wave_speed = 0.2
  @show_fps = nil
  @game_paused = nil
  @water_level = 0 # as this gets higher, the ship gets lower in the water
  # some magic numbers worked out based on the ship sprite
  @radius1 = 164.2680736
  @radius2 = 111.3058848
  @radius3 = 140.8687332
  @dangle1 = 0.8370762479
  @dangle2 = 0.1533323884
  @dangle3 = 0.8960553846
  @convert = Math::PI / 180
  @chains = { x: 0, y: 0, w: 70, h: 910, path: "sprites/chains.png" }
  # fish inspiration from 09_performance/01_sprites_as_hash sample
  @fish_colors_weighted = [
    { r: 255, g: 173, b: 173 }, # FFADAD
    { r: 255, g: 214, b: 165 }, # FFD6A5
    { r: 253, g: 255, b: 182 }, # FDFFB6
    { r: 202, g: 255, b: 191 }, # CAFFBF
    { r: 155, g: 246, b: 255 }, # 9BF6FF
    { r: 160, g: 196, b: 255 }, # A0C4FF
    { r: 189, g: 178, b: 255 }, # BDB2FF
    { r: 255, g: 198, b: 255 }  # FFC6FF
  ]
  @fish_sizes_weighted = [
    { h: 32, w: 32 },
    { h: 48, w: 48 },
    { h: 48, w: 48 },
    { h: 48, w: 64 },
    { h: 48, w: 64 },
    { h: 48, w: 64 },
    { h: 64, w: 64 },
    { h: 64, w: 64 },
    { h: 64, w: 64 },
    { h: 64, w: 64 },
    { h: 64, w: 80 },
    { h: 64, w: 80 },
    { h: 64, w: 80 },
    { h: 80, w: 96 },
    { h: 80, w: 96 },
    { h: 96, w: 96 }
  ]
  @fish = 100.map { |i| new_fish }
  @anchors = {
    left: {
      state: :idle,
      ship: 
      {
        x: 0,
        y: 0
      },
      anchor: 
      {
        x: 0,
        y: 0
      },
      target: 
      {
        x: 0,
        y: 0
      },
      duration: 0,
      start: 0,
      angle: 0,
      clump: []
    },
    middle: {
      state: :idle,
      ship: 
      {
        x: 0,
        y: 0
      },
      anchor: 
      {
        x: 0,
        y: 0
      },
      target: 
      {
        x: 0,
        y: 0
      },
      duration: 0,
      start: 0,
      angle: 0,
      clump: []
    },
    right: {
      state: :idle,
      ship: 
      {
        x: 0,
        y: 0
      },
      anchor:
      {
        x: 0,
        y: 0
      },
      target: 
      {
        x: 0,
        y: 0
      },
      duration: 0,
      start: 0,
      angle: 0,
      clump: []
    }
  }
  # techinically not everything is set yet, but it should be when the end is reached
  @args_state.defaults_set = true
  @position = { # used to follow the front most wave
    0 => { y: 384.0, angle: 0.0 },
    1 => { y: 383.9997108520141, angle: -0.028903126681082850 },
    2 => { y: 383.9988434150238, angle: -0.057805537606334200 },
    3 => { y: 383.9973977099306, angle: -0.086706517041991300 },
    4 => { y: 383.9953737715696, angle: -0.115605349297575300 },
    5 => { y: 383.9927716487089, angle: -0.14450131874568300 },
    6 => { y: 383.9895914040486, angle: -0.173393709846465050 },
    7 => { y: 383.9858331142185, angle: -0.202281807167125900 },
    8 => { y: 383.9814968697773, angle: -0.231164895403407700 },
    9 => { y: 383.9765827752098, angle: -0.26004225940206300 },
    10 => { y: 383.9710909489241, angle: -0.288913184182182350 },
    11 => { y: 383.9650215232496, angle: -0.31777695495523450 },
    12 => { y: 383.9583746444331, angle: -0.346632857148223400 },
    13 => { y: 383.9511504726357, angle: -0.375480176424844600 },
    14 => { y: 383.9433491819283, angle: -0.404318198705635400 },
    15 => { y: 383.9349709602886, angle: -0.433146210190669250 },
    16 => { y: 383.9260160095951, angle: -0.461963497380673750 },
    17 => { y: 383.9164845456234, angle: -0.490769347098275150 },
    18 => { y: 383.9063767980405, angle: -0.51956304650880050 },
    19 => { y: 383.8956930103993, angle: -0.54834388314276800 },
    20 => { y: 383.8844334401327, angle: -0.57711114491580100 },
    21 => { y: 383.8725983585476, angle: -0.60586412015093900 },
    22 => { y: 383.8601880508183, angle: -0.63460209759964800 },
    23 => { y: 383.8472028159792, angle: -0.66332436646266950 },
    24 => { y: 383.8336429669182, angle: -0.6920302164108450 },
    25 => { y: 383.819508830369, angle: -0.72071893760833400 },
    26 => { y: 383.8048007469031, angle: -0.74938982073054950 },
    27 => { y: 383.7895190709212, angle: -0.7780421569876100 },
    28 => { y: 383.7736641706459, angle: -0.80667523814449700 },
    29 => { y: 383.7572364281112, angle: -0.83528835654288900 },
    30 => { y: 383.7402362391547, angle: -0.863880805119700 },
    31 => { y: 383.7226640134073, angle: -0.89245187743169950 },
    32 => { y: 383.7045201742833, angle: -0.92100086767313700 },
    33 => { y: 383.6858051589707, angle: -0.94952707069816700 },
    34 => { y: 383.6665194184203, angle: -0.97802978204125450 },
    35 => { y: 383.6466634173346, angle: -1.00650829793811250 },
    36 => { y: 383.6262376341574, angle: -1.03496191534632350 },
    37 => { y: 383.6052425610615, angle: -1.06338993196478650 },
    38 => { y: 383.5836787039371, angle: -1.09179164625739350 },
    39 => { y: 383.5615465823797, angle: -1.12016635746998850 },
    40 => { y: 383.5388467296776, angle: -1.14851336565283050 },
    41 => { y: 383.5155796927986, angle: -1.17683197168102900 },
    42 => { y: 383.4917460323778, angle: -1.20512147727422750 },
    43 => { y: 383.4673463227028, angle: -1.23338118501752900 },
    44 => { y: 383.4423811517009, angle: -1.26161039838081200 },
    45 => { y: 383.4168511209247, angle: -1.28980842174027900 },
    46 => { y: 383.3907568455371, angle: -1.31797456039755100 },
    47 => { y: 383.3640989542971, angle: -1.34610812060041550 },
    48 => { y: 383.3368780895443, angle: -1.37420840956211200 },
    49 => { y: 383.3090949071835, angle: -1.40227473548213800 },
    50 => { y: 383.2807500766691, angle: -1.43030640756572250 },
    51 => { y: 383.2518442809885, angle: -1.45830273604269050 },
    52 => { y: 383.2223782166462, angle: -1.48626303218968450 },
    53 => { y: 383.1923525936466, angle: -1.51418660834708450 },
    54 => { y: 383.1617681354771, angle: -1.54207277794027650 },
    55 => { y: 383.1306255790905, angle: -1.56992085549917300 },
    56 => { y: 383.0989256748875, angle: -1.59773015667668100 },
    57 => { y: 383.0666691866983, angle: -1.62549999826925300 },
    58 => { y: 383.0338568917646, angle: -1.6532296982348300 },
    59 => { y: 383.0004895807203, angle: -1.68091857571413250 },
    60 => { y: 382.966568057573, angle: -1.70856595104792850 },
    61 => { y: 382.9320931396845, angle: -1.7361711457963750 },
    62 => { y: 382.8970656577507, angle: -1.76373348275971950 },
    63 => { y: 382.8614864557823, angle: -1.7912522859944100 },
    64 => { y: 382.8253563910837, angle: -1.81872688083552700 },
    65 => { y: 382.7886763342329, angle: -1.84615659391121750 },
    66 => { y: 382.7514471690602, angle: -1.87354075316586850 },
    67 => { y: 382.7136697926273, angle: -1.90087868787512750 },
    68 => { y: 382.6753451152051, angle: -1.9281697286666900 },
    69 => { y: 382.6364740602522, angle: -1.95541320753718900 },
    70 => { y: 382.5970575643925, angle: -1.98260845787186750 },
    71 => { y: 382.5570965773928, angle: -2.00975481446205850 },
    72 => { y: 382.5165920621396, angle: -2.03685161352331100 },
    73 => { y: 382.4755449946163, angle: -2.06389819271374700 },
    74 => { y: 382.433956363879, angle: -2.09089389115234400 },
    75 => { y: 382.3918271720337, angle: -2.11783804943588700 },
    76 => { y: 382.3491584342113, angle: -2.14473000965769550 },
    77 => { y: 382.3059511785433, angle: -2.1715691154250150 },
    78 => { y: 382.2622064461374, angle: -2.19835471187662400 },
    79 => { y: 382.2179252910519, angle: -2.22508614569981150 },
    80 => { y: 382.1731087802709, angle: -2.25176276514898600 },
    81 => { y: 382.1277579936778, angle: -2.27838392006267050 },
    82 => { y: 382.0818740240302, angle: -2.30494896187900050 },
    83 => { y: 382.0354579769329, angle: -2.33145724365612600 },
    84 => { y: 381.9885109708113, angle: -2.35790812008559650 },
    85 => { y: 381.9410341368848, angle: -2.38430094751291650 },
    86 => { y: 381.8930286191392, angle: -2.41063508395093100 },
    87 => { y: 381.8444955742996, angle: -2.43690988909939800 },
    88 => { y: 381.795436171802, angle: -2.46312472435980100 },
    89 => { y: 381.7458515937652, angle: -2.48927895285279550 },
    90 => { y: 381.6957430349627, angle: -2.51537193943473400 },
    91 => { y: 381.6451117027935, angle: -2.54140305071270250 },
    92 => { y: 381.5939588172533, angle: -2.56737165506261150 },
    93 => { y: 381.542285610905, angle: -2.59327712264423700 },
    94 => { y: 381.4900933288487, angle: -2.61911882541661800 },
    95 => { y: 381.4373832286923, angle: -2.64489613715579850 },
    96 => { y: 381.3841565805208, angle: -2.67060843346880850 },
    97 => { y: 381.3304146668656, angle: -2.69625509181098050 },
    98 => { y: 381.2761587826739, angle: -2.72183549149979650 },
    99 => { y: 381.2213902352774, angle: -2.74734901373163400 },
    100 => { y: 381.1661103443605, angle: -2.77279504159732050 },
    101 => { y: 381.1103204419292, angle: -2.79817296009604250 },
    102 => { y: 381.0540218722782, angle: -2.82348215615189350 },
    103 => { y: 380.997215991959, angle: -2.84872201862821450 },
    104 => { y: 380.9399041697471, angle: -2.87389193834286150 },
    105 => { y: 380.8820877866091, angle: -2.89899130808255150 },
    106 => { y: 380.8237682356691, angle: -2.92401952261826900 },
    107 => { y: 380.7649469221755, angle: -2.94897597871919200 },
    108 => { y: 380.705625263467, angle: -2.97386007516852350 },
    109 => { y: 380.6458046889385, angle: -2.99867121277529200 },
    110 => { y: 380.5854866400065, angle: -3.0234087943914600 },
    111 => { y: 380.5246725700746, angle: -3.04807222492457700 },
    112 => { y: 380.4633639444982, angle: -3.07266091135163250 },
    113 => { y: 380.4015622405495, angle: -3.09717426273439700 },
    114 => { y: 380.3392689473816, angle: -3.12161169023200800 },
    115 => { y: 380.2764855659929, angle: -3.14597260711447150 },
    116 => { y: 380.2132136091909, angle: -3.17025642877779450 },
    117 => { y: 380.1494546015553, angle: -3.19446257275565400 },
    118 => { y: 380.0852100794018, angle: -3.21859045873453400 },
    119 => { y: 380.0204815907451, angle: -3.24263950856538900 },
    120 => { y: 379.955270695261, angle: -3.26660914627780450 },
    121 => { y: 379.8895789642497, angle: -3.29049879809279350 },
    122 => { y: 379.823407980597, angle: -3.31430789243582300 },
    123 => { y: 379.7567593387367, angle: -3.33803585994920400 },
    124 => { y: 379.6896346446123, angle: -3.36168213350539750 },
    125 => { y: 379.622035515638, angle: -3.38524614821898950 },
    126 => { y: 379.5539635806597, angle: -3.40872734146000350 },
    127 => { y: 379.4854204799161, angle: -3.43212515286517650 },
    128 => { y: 379.4164078649987, angle: -3.45543902435057250 },
    129 => { y: 379.3469273988125, angle: -3.47866840012498600 },
    130 => { y: 379.2769807555355, angle: -3.50181272669960050 },
    131 => { y: 379.2065696205786, angle: -3.52487145290238950 },
    132 => { y: 379.135695690545, angle: -3.54784402988806850 },
    133 => { y: 379.0643606731892, angle: -3.57072991114996150 },
    134 => { y: 378.9925662873758, angle: -3.59352855253293750 },
    135 => { y: 378.9203142630386, angle: -3.61623941224331250 },
    136 => { y: 378.8476063411379, angle: -3.63886195086151450 },
    137 => { y: 378.7744442736196, angle: -3.66139563135157650 },
    138 => { y: 378.7008298233724, angle: -3.68383991907410050 },
    139 => { y: 378.6267647641855, angle: -3.70619428179648150 },
    140 => { y: 378.5522508807057, angle: -3.72845818970305250 },
    141 => { y: 378.4772899683946, angle: -3.75063111540716800 },
    142 => { y: 378.4018838334854, angle: -3.77271253396151750 },
    143 => { y: 378.3260342929391, angle: -3.79470192286781950 },
    144 => { y: 378.2497431744007, angle: -3.81659876208829200 },
    145 => { y: 378.1730123161557, angle: -3.83840253405522600 },
    146 => { y: 378.0958435670848, angle: -3.86011272368191900 },
    147 => { y: 378.0182387866208, angle: -3.88172881837241250 },
    148 => { y: 377.9401998447023, angle: -3.90325030803146550 },
    149 => { y: 377.8617286217296, angle: -3.92467668507417650 },
    150 => { y: 377.782827008519, angle: -3.94600744443655350 },
    151 => { y: 377.7034969062575, angle: -3.96724208358446300 },
    152 => { y: 377.6237402264565, angle: -3.98838010252351600 },
    153 => { y: 377.5435588909064, angle: -4.00942100380820350 },
    154 => { y: 377.4629548316298, angle: -4.03036429255180800 },
    155 => { y: 377.3819299908352, angle: -4.05120947643557900 },
    156 => { y: 377.30048632087, angle: -4.07195606571642400 },
    157 => { y: 377.2186257841738, angle: -4.09260357323851600 },
    158 => { y: 377.1363503532304, angle: -4.1131515144397600 },
    159 => { y: 377.0536620105214, angle: -4.13359940736231100 },
    160 => { y: 376.9705627484772, angle: -4.15394677266021450 },
    161 => { y: 376.8870545694298, angle: -4.17419313360869200 },
    162 => { y: 376.8031394855645, angle: -4.19433801611169050 },
    163 => { y: 376.7188195188712, angle: -4.21438094871178350 },
    164 => { y: 376.6340967010953, angle: -4.23432146259705700 },
    165 => { y: 376.5489730736896, angle: -4.25415909161021550 },
    166 => { y: 376.4634506877646, angle: -4.27389337225580400 },
    167 => { y: 376.3775316040391, angle: -4.29352384370894350 },
    168 => { y: 376.2912178927906, angle: -4.31305004782260850 },
    169 => { y: 376.2045116338053, angle: -4.3324715291361350 },
    170 => { y: 376.1174149163284, angle: -4.35178783488255950 },
    171 => { y: 376.0299298390132, angle: -4.37099851499492550 },
    172 => { y: 375.9420585098708, angle: -4.3901031221165050 },
    173 => { y: 375.8538030462194, angle: -4.40910121160590700 },
    174 => { y: 375.765165574633, angle: -4.4279923415446750 },
    175 => { y: 375.6761482308906, angle: -4.44677607274500250 },
    176 => { y: 375.5867531599244, angle: -4.46545196875711900 },
    177 => { y: 375.496982515768, angle: -4.48401959587523950 },
    178 => { y: 375.4068384615048, angle: -4.50247852314531100 },
    179 => { y: 375.316323169216, angle: -4.52082832237116550 },
    180 => { y: 375.2254388199274, angle: -4.53906856812206650 },
    181 => { y: 375.1341876035584, angle: -4.55719883773809550 },
    182 => { y: 375.0425717188673, angle: -4.57521871133805150 },
    183 => { y: 374.9505933734, angle: -4.59312777182464350 },
    184 => { y: 374.858254783436, angle: -4.61092560489148200 },
    185 => { y: 374.7655581739351, angle: -4.6286117990293400 },
    186 => { y: 374.6725057784836, angle: -4.6461859455316850 },
    187 => { y: 374.5790998392411, angle: -4.66364763850159200 },
    188 => { y: 374.4853426068857, angle: -4.68099647485735950 },
    189 => { y: 374.3912363405605, angle: -4.69823205433796700 },
    190 => { y: 374.2967833078184, angle: -4.71535397950864650 },
    191 => { y: 374.2019857845683, angle: -4.73236185576882400 },
    192 => { y: 374.1068460550194, angle: -4.74925529135427200 },
    193 => { y: 374.0113664116269, angle: -4.76603389734486700 },
    194 => { y: 373.9155491550363, angle: -4.78269728767021900 },
    195 => { y: 373.8193965940283, angle: -4.79924507911387450 },
    196 => { y: 373.7229110454627, angle: -4.81567689131848800 },
    197 => { y: 373.6260948342231, angle: -4.83199234679266200 },
    198 => { y: 373.5289502931604, angle: -4.84819107091425900 },
    199 => { y: 373.4314797630371, angle: -4.86427269193650550 },
    200 => { y: 373.3336855924705, angle: -4.8802368409922600 },
    201 => { y: 373.2355701378761, angle: -4.89608315209939200 },
    202 => { y: 373.1371357634111, angle: -4.91181126216515900 },
    203 => { y: 373.0383848409174, angle: -4.92742081099100400 },
    204 => { y: 372.939319749864, angle: -4.94291144127789650 },
    205 => { y: 372.8399428772903, angle: -4.95828279862956100 },
    206 => { y: 372.7402566177482, angle: -4.97353453155808550 },
    207 => { y: 372.6402633732445, angle: -4.9886662914876950 },
    208 => { y: 372.5399655531828, angle: -5.0036777327592250 },
    209 => { y: 372.439365574306, angle: -5.0185685126345800 },
    210 => { y: 372.3384658606373, angle: -5.033338291300650 },
    211 => { y: 372.2372688434227, angle: -5.0479867318730450 },
    212 => { y: 372.1357769610716, angle: -5.0625135004012700 },
    213 => { y: 372.0339926590985, angle: -5.0769182658720450 },
    214 => { y: 371.9319183900637, angle: -5.0912007002120850 },
    215 => { y: 371.8295566135148, angle: -5.1053604782938100 },
    216 => { y: 371.7269097959269, angle: -5.1193972779386800 },
    217 => { y: 371.6239804106434, angle: -5.1333107799191350 },
    218 => { y: 371.5207709378163, angle: -5.1471006679644600 },
    219 => { y: 371.4172838643465, angle: -5.1607666287629850 },
    220 => { y: 371.3135216838239, angle: -5.1743083519663100 },
    221 => { y: 371.2094868964675, angle: -5.1877255301922250 },
    222 => { y: 371.1051820090644, angle: -5.2010178590282050 },
    223 => { y: 371.0006095349105, angle: -5.2141850370346550 },
    224 => { y: 370.8957719937491, angle: -5.2272267657480050 },
    225 => { y: 370.7906719117106, angle: -5.2401427496845300 },
    226 => { y: 370.6853118212512, angle: -5.2529326963427650 },
    227 => { y: 370.5796942610926, angle: -5.2655963162067650 },
    228 => { y: 370.4738217761602, angle: -5.2781333227490050 },
    229 => { y: 370.3676969175219, angle: -5.2905434324333750 },
    230 => { y: 370.2613222423268, angle: -5.3028263647183650 },
    231 => { y: 370.1547003137435, angle: -5.3149818420596950 },
    232 => { y: 370.0478337008983, angle: -5.3270095899119850 },
    233 => { y: 369.9407249788134, angle: -5.3389093367335200 },
    234 => { y: 369.8333767283447, angle: -5.3506808139871100 },
    235 => { y: 369.7257915361197, angle: -5.3623237561440750 },
    236 => { y: 369.6179719944754, angle: -5.3738379006849700 },
    237 => { y: 369.5099207013952, angle: -5.3852229881041850 },
    238 => { y: 369.4016402604469, angle: -5.3964787619111600 },
    239 => { y: 369.29313328072, angle: -5.4076049686321950 },
    240 => { y: 369.1844023767622, angle: -5.4186013578143900 },
    241 => { y: 369.075450168517, angle: -5.4294676820266450 },
    242 => { y: 368.9662792812604, angle: -5.4402036968628400 },
    243 => { y: 368.8568923455376, angle: -5.4508091609427350 },
    244 => { y: 368.7472919970996, angle: -5.4612838359153200 },
    245 => { y: 368.6374808768397, angle: -5.4716274864605100 },
    246 => { y: 368.52746163073, angle: -5.4818398802909850 },
    247 => { y: 368.4172369097574, angle: -5.4919207881538050 },
    248 => { y: 368.3068093698598, angle: -5.5018699838338700 },
    249 => { y: 368.1961816718625, angle: -5.5116872441541900 },
    250 => { y: 368.0853564814133, angle: -5.5213723489784150 },
    251 => { y: 367.974336468919, angle: -5.5309250812124300 },
    252 => { y: 367.8631243094806, angle: -5.5403452268072600 },
    253 => { y: 367.7517226828293, angle: -5.5496325747586150 },
    254 => { y: 367.6401342732612, angle: -5.5587869171108350 },
    255 => { y: 367.5283617695734, angle: -5.5678080489566700 },
    256 => { y: 367.4164078649987, angle: -5.5766957684404350 },
    257 => { y: 367.3042752571411, angle: -5.5854498767587250 },
    258 => { y: 367.1919666479101, angle: -5.5940701781616900 },
    259 => { y: 367.0794847434567, angle: -5.6025564799561800 },
    260 => { y: 366.9668322541071, angle: -5.6109085925045950 },
    261 => { y: 366.854011894298, angle: -5.6191263292285450 },
    262 => { y: 366.7410263825111, angle: -5.6272095066088900 },
    263 => { y: 366.6278784412073, angle: -5.6351579441883600 },
    264 => { y: 366.5145707967618, angle: -5.6429714645715450 },
    265 => { y: 366.4011061793976, angle: -5.6506498934268900 },
    266 => { y: 366.2874873231201, angle: -5.6581930594880700 },
    267 => { y: 366.1737169656514, angle: -5.6656007945546350 },
    268 => { y: 366.0597978483638, angle: -5.6728729334934850 },
    269 => { y: 365.9457327162144, angle: -5.680009314240600 },
    270 => { y: 365.8315243176783, angle: -5.6870097778010550 },
    271 => { y: 365.7171754046831, angle: -5.6938741682510100 },
    272 => { y: 365.6026887325417, angle: -5.7006023327379100 },
    273 => { y: 365.4880670598869, angle: -5.7071941214829050 },
    274 => { y: 365.373313148604, angle: -5.7136493877802900 },
    275 => { y: 365.2584297637649, angle: -5.7199679879997250 },
    276 => { y: 365.1434196735612, angle: -5.726149781585950 },
    277 => { y: 365.0282856492377, angle: -5.7321946310613600 },
    278 => { y: 364.9130304650251, angle: -5.7381024020248600 },
    279 => { y: 364.797656898074, angle: -5.7438729631545300 },
    280 => { y: 364.6821677283871, angle: -5.7495061862075800 },
    281 => { y: 364.5665657387528, angle: -5.7550019460212900 },
    282 => { y: 364.4508537146782, angle: -5.7603601205134950 },
    283 => { y: 364.3350344443213, angle: -5.7655805906840650 },
    284 => { y: 364.2191107184245, angle: -5.7706632406151950 },
    285 => { y: 364.1030853302472, angle: -5.7756079574720450 },
    286 => { y: 363.9869610754984, angle: -5.7804146315034050 },
    287 => { y: 363.8707407522691, angle: -5.7850831560429900 },
    288 => { y: 363.7544271609656, angle: -5.7896134275091350 },
    289 => { y: 363.638023104241, angle: -5.7940053454059100 },
    290 => { y: 363.5215313869287, angle: -5.7982588123239050 },
    291 => { y: 363.4049548159741, angle: -5.8023737339403250 },
    292 => { y: 363.2882962003672, angle: -5.8063500190202050 },
    293 => { y: 363.1715583510751, angle: -5.8101875794157650 },
    294 => { y: 363.0547440809739, angle: -5.8138863300687250 },
    295 => { y: 362.9378562047812, angle: -5.8174461890085200 },
    296 => { y: 362.8208975389881, angle: -5.8208670773552800 },
    297 => { y: 362.7038709017916, angle: -5.8241489193179150 },
    298 => { y: 362.5867791130262, angle: -5.82729164219650 },
    299 => { y: 362.4696249940967, angle: -5.8302951763810350 },
    300 => { y: 362.3524113679094, angle: -5.8331594553531150 },
    301 => { y: 362.2351410588048, angle: -5.8358844156855250 },
    302 => { y: 362.1178168924889, angle: -5.8384699970433250 },
    303 => { y: 362.0004416959655, angle: -5.8409161421832950 },
    304 => { y: 361.8830182974683, angle: -5.843222796954700 },
    305 => { y: 361.765549526392, angle: -5.8453899102997300 },
    306 => { y: 361.648038213225, angle: -5.8474174342532750 },
    307 => { y: 361.5304871894804, angle: -5.8493053239438750 },
    308 => { y: 361.4128992876285, angle: -5.8510535375939200 },
    309 => { y: 361.2952773410281, angle: -5.8526620365186450 },
    310 => { y: 361.177624183858, angle: -5.8541307851281200 },
    311 => { y: 361.0599426510497, angle: -5.8554597509262150 },
    312 => { y: 360.9422355782177, angle: -5.8566489045109350 },
    313 => { y: 360.8245058015924, angle: -5.8576982195751700 },
    314 => { y: 360.7067561579511, angle: -5.8586076729064450 },
    315 => { y: 360.5889894845499, angle: -5.8593772443868600 },
    316 => { y: 360.4712086190551, angle: -5.86000691699350 },
    317 => { y: 360.3534163994751, angle: -5.8604966767980850 },
    318 => { y: 360.2356156640916, angle: -5.8608465129677850 },
    319 => { y: 360.117809251392, angle: -5.8610564177647400 },
    320 => { y: 360.0, angle: -5.8611263865462800 },
    321 => { y: 359.882190748608, angle: -5.8610564177647400 },
    322 => { y: 359.7643843359084, angle: -5.8608465129677850 },
    323 => { y: 359.646583600525, angle: -5.8604966767980850 },
    324 => { y: 359.5287913809449, angle: -5.86000691699350 },
    325 => { y: 359.4110105154501, angle: -5.8593772443868600 },
    326 => { y: 359.2932438420489, angle: -5.8586076729064450 },
    327 => { y: 359.1754941984076, angle: -5.857698219575450 },
    328 => { y: 359.0577644217823, angle: -5.8566489045109350 },
    329 => { y: 358.9400573489504, angle: -5.8554597509262150 },
    330 => { y: 358.822375816142, angle: -5.8541307851281200 },
    331 => { y: 358.704722658972, angle: -5.8526620365186450 },
    332 => { y: 358.5871007123715, angle: -5.8510535375939200 },
    333 => { y: 358.4695128105196, angle: -5.8493053239441550 },
    334 => { y: 358.351961786775, angle: -5.8474174342532750 },
    335 => { y: 358.234450473608, angle: -5.8453899102997300 },
    336 => { y: 358.1169817025317, angle: -5.843222796954700 },
    337 => { y: 357.9995583040345, angle: -5.8409161421832950 },
    338 => { y: 357.8821831075111, angle: -5.8384699970433250 },
    339 => { y: 357.7648589411952, angle: -5.8358844156856650 },
    340 => { y: 357.6475886320906, angle: -5.8331594553531150 },
    341 => { y: 357.5303750059033, angle: -5.8302951763811750 },
    342 => { y: 357.4132208869738, angle: -5.82729164219650 },
    343 => { y: 357.2961290982084, angle: -5.8241489193179150 },
    344 => { y: 357.1791024610119, angle: -5.8208670773552800 },
    345 => { y: 357.0621437952188, angle: -5.8174461890085200 },
    346 => { y: 356.9452559190261, angle: -5.8138863300687250 },
    347 => { y: 356.8284416489249, angle: -5.8101875794157650 },
    348 => { y: 356.7117037996328, angle: -5.8063500190202050 },
    349 => { y: 356.5950451840259, angle: -5.8023737339403250 },
    350 => { y: 356.4784686130713, angle: -5.7982588123239050 },
    351 => { y: 356.361976895759, angle: -5.7940053454059100 },
    352 => { y: 356.2455728390344, angle: -5.7896134275091350 },
    353 => { y: 356.1292592477309, angle: -5.7850831560429900 },
    354 => { y: 356.0130389245016, angle: -5.7804146315034050 },
    355 => { y: 355.8969146697528, angle: -5.7756079574720450 },
    356 => { y: 355.7808892815755, angle: -5.7706632406151950 },
    357 => { y: 355.6649655556787, angle: -5.7655805906840650 },
    358 => { y: 355.5491462853218, angle: -5.7603601205134950 },
    359 => { y: 355.4334342612472, angle: -5.7550019460212900 },
    360 => { y: 355.3178322716129, angle: -5.7495061862075800 },
    361 => { y: 355.202343101926, angle: -5.7438729631545300 },
    362 => { y: 355.0869695349749, angle: -5.7381024020248600 },
    363 => { y: 354.9717143507623, angle: -5.7321946310613600 },
    364 => { y: 354.8565803264388, angle: -5.726149781585950 },
    365 => { y: 354.7415702362351, angle: -5.7199679879997250 },
    366 => { y: 354.626686851396, angle: -5.7136493877802900 },
    367 => { y: 354.5119329401131, angle: -5.7071941214829050 },
    368 => { y: 354.3973112674583, angle: -5.7006023327379100 },
    369 => { y: 354.2828245953169, angle: -5.6938741682510100 },
    370 => { y: 354.1684756823217, angle: -5.6870097778010550 },
    371 => { y: 354.0542672837856, angle: -5.680009314240600 },
    372 => { y: 353.9402021516362, angle: -5.6728729334934850 },
    373 => { y: 353.8262830343486, angle: -5.6656007945546350 },
    374 => { y: 353.7125126768799, angle: -5.6581930594880700 },
    375 => { y: 353.5988938206024, angle: -5.6506498934268900 },
    376 => { y: 353.4854292032382, angle: -5.6429714645715450 },
    377 => { y: 353.3721215587927, angle: -5.6351579441883600 },
    378 => { y: 353.2589736174889, angle: -5.6272095066088900 },
    379 => { y: 353.145988105702, angle: -5.6191263292285450 },
    380 => { y: 353.0331677458929, angle: -5.6109085925045950 },
    381 => { y: 352.9205152565433, angle: -5.6025564799561800 },
    382 => { y: 352.8080333520899, angle: -5.5940701781616900 },
    383 => { y: 352.6957247428589, angle: -5.5854498767587250 },
    384 => { y: 352.5835921350013, angle: -5.5766957684402950 },
    385 => { y: 352.4716382304266, angle: -5.5678080489566700 },
    386 => { y: 352.3598657267388, angle: -5.5587869171108350 },
    387 => { y: 352.2482773171707, angle: -5.5496325747586150 },
    388 => { y: 352.1368756905194, angle: -5.5403452268072600 },
    389 => { y: 352.025663531081, angle: -5.5309250812124300 },
    390 => { y: 351.9146435185867, angle: -5.5213723489784150 },
    391 => { y: 351.8038183281375, angle: -5.5116872441541900 },
    392 => { y: 351.6931906301402, angle: -5.5018699838338700 },
    393 => { y: 351.5827630902426, angle: -5.4919207881538050 },
    394 => { y: 351.4725383692701, angle: -5.4818398802909850 },
    395 => { y: 351.3625191231603, angle: -5.4716274864605100 },
    396 => { y: 351.2527080029004, angle: -5.4612838359153200 },
    397 => { y: 351.1431076544624, angle: -5.4508091609427350 },
    398 => { y: 351.0337207187396, angle: -5.4402036968628400 },
    399 => { y: 350.924549831483, angle: -5.4294676820266450 },
    400 => { y: 350.8155976232378, angle: -5.4186013578143900 },
    401 => { y: 350.70686671928, angle: -5.4076049686321950 },
    402 => { y: 350.5983597395531, angle: -5.3964787619111600 },
    403 => { y: 350.4900792986048, angle: -5.3852229881041850 },
    404 => { y: 350.3820280055246, angle: -5.3738379006851100 },
    405 => { y: 350.2742084638803, angle: -5.3623237561440750 },
    406 => { y: 350.1666232716553, angle: -5.3506808139871100 },
    407 => { y: 350.0592750211866, angle: -5.3389093367335200 },
    408 => { y: 349.9521662991017, angle: -5.3270095899119850 },
    409 => { y: 349.8452996862565, angle: -5.3149818420596950 },
    410 => { y: 349.7386777576732, angle: -5.3028263647183650 },
    411 => { y: 349.6323030824781, angle: -5.2905434324333750 },
    412 => { y: 349.5261782238398, angle: -5.2781333227490050 },
    413 => { y: 349.4203057389074, angle: -5.2655963162067650 },
    414 => { y: 349.3146881787488, angle: -5.2529326963427650 },
    415 => { y: 349.2093280882894, angle: -5.2401427496845300 },
    416 => { y: 349.1042280062509, angle: -5.2272267657480050 },
    417 => { y: 348.9993904650895, angle: -5.2141850370346550 },
    418 => { y: 348.8948179909356, angle: -5.2010178590282050 },
    419 => { y: 348.7905131035325, angle: -5.1877255301922250 },
    420 => { y: 348.6864783161761, angle: -5.1743083519663100 },
    421 => { y: 348.5827161356535, angle: -5.1607666287629850 },
    422 => { y: 348.4792290621837, angle: -5.1471006679644600 },
    423 => { y: 348.3760195893566, angle: -5.1333107799191350 },
    424 => { y: 348.2730902040731, angle: -5.1193972779386800 },
    425 => { y: 348.1704433864852, angle: -5.1053604782938100 },
    426 => { y: 348.0680816099363, angle: -5.0912007002120850 },
    427 => { y: 347.9660073409015, angle: -5.0769182658720450 },
    428 => { y: 347.8642230389284, angle: -5.0625135004012700 },
    429 => { y: 347.7627311565773, angle: -5.0479867318730450 },
    430 => { y: 347.6615341393627, angle: -5.033338291300650 },
    431 => { y: 347.560634425694, angle: -5.0185685126345800 },
    432 => { y: 347.4600344468172, angle: -5.0036777327592250 },
    433 => { y: 347.3597366267555, angle: -4.9886662914876950 },
    434 => { y: 347.2597433822518, angle: -4.97353453155808550 },
    435 => { y: 347.1600571227097, angle: -4.95828279862956100 },
    436 => { y: 347.060680250136, angle: -4.94291144127789650 },
    437 => { y: 346.9616151590826, angle: -4.92742081099100400 },
    438 => { y: 346.8628642365889, angle: -4.91181126216515900 },
    439 => { y: 346.7644298621239, angle: -4.89608315209939200 },
    440 => { y: 346.6663144075295, angle: -4.8802368409922600 },
    441 => { y: 346.5685202369629, angle: -4.86427269193650550 },
    442 => { y: 346.4710497068396, angle: -4.84819107091425900 },
    443 => { y: 346.3739051657769, angle: -4.83199234679266200 },
    444 => { y: 346.2770889545373, angle: -4.81567689131848800 },
    445 => { y: 346.1806034059717, angle: -4.79924507911387450 },
    446 => { y: 346.0844508449637, angle: -4.78269728767021900 },
    447 => { y: 345.9886335883731, angle: -4.76603389734486700 },
    448 => { y: 345.8931539449806, angle: -4.74925529135427200 },
    449 => { y: 345.7980142154317, angle: -4.73236185576882400 },
    450 => { y: 345.7032166921816, angle: -4.71535397950878700 },
    451 => { y: 345.6087636594395, angle: -4.69823205433796700 },
    452 => { y: 345.5146573931143, angle: -4.68099647485735950 },
    453 => { y: 345.4209001607589, angle: -4.66364763850159200 },
    454 => { y: 345.3274942215164, angle: -4.6461859455316850 },
    455 => { y: 345.2344418260649, angle: -4.62861179902919900 },
    456 => { y: 345.141745216564, angle: -4.61092560489148200 },
    457 => { y: 345.0494066266, angle: -4.59312777182464350 },
    458 => { y: 344.9574282811327, angle: -4.57521871133805150 },
    459 => { y: 344.8658123964416, angle: -4.55719883773809550 },
    460 => { y: 344.7745611800725, angle: -4.53906856812206650 },
    461 => { y: 344.683676830784, angle: -4.52082832237116550 },
    462 => { y: 344.5931615384952, angle: -4.50247852314531100 },
    463 => { y: 344.503017484232, angle: -4.48401959587523950 },
    464 => { y: 344.4132468400756, angle: -4.46545196875711900 },
    465 => { y: 344.3238517691094, angle: -4.44677607274500250 },
    466 => { y: 344.234834425367, angle: -4.4279923415446750 },
    467 => { y: 344.1461969537806, angle: -4.40910121160590700 },
    468 => { y: 344.0579414901292, angle: -4.3901031221165050 },
    469 => { y: 343.9700701609868, angle: -4.37099851499492550 },
    470 => { y: 343.8825850836716, angle: -4.35178783488241800 },
    471 => { y: 343.7954883661947, angle: -4.3324715291361350 },
    472 => { y: 343.7087821072094, angle: -4.31305004782260850 },
    473 => { y: 343.6224683959609, angle: -4.29352384370894350 },
    474 => { y: 343.5365493122354, angle: -4.27389337225580400 },
    475 => { y: 343.4510269263104, angle: -4.25415909161035700 },
    476 => { y: 343.3659032989047, angle: -4.23432146259705700 },
    477 => { y: 343.2811804811288, angle: -4.21438094871164300 },
    478 => { y: 343.1968605144355, angle: -4.19433801611169050 },
    479 => { y: 343.1129454305702, angle: -4.17419313360869200 },
    480 => { y: 343.0294372515228, angle: -4.15394677266021450 },
    481 => { y: 342.9463379894786, angle: -4.13359940736231100 },
    482 => { y: 342.8636496467696, angle: -4.1131515144397600 },
    483 => { y: 342.7813742158262, angle: -4.09260357323851600 },
    484 => { y: 342.69951367913, angle: -4.07195606571642400 },
    485 => { y: 342.6180700091648, angle: -4.05120947643557900 },
    486 => { y: 342.5370451683702, angle: -4.03036429255180800 },
    487 => { y: 342.4564411090936, angle: -4.00942100380820350 },
    488 => { y: 342.3762597735435, angle: -3.98838010252351600 },
    489 => { y: 342.2965030937425, angle: -3.96724208358446300 },
    490 => { y: 342.217172991481, angle: -3.94600744443655350 },
    491 => { y: 342.1382713782704, angle: -3.92467668507417650 },
    492 => { y: 342.0598001552977, angle: -3.90325030803146550 },
    493 => { y: 341.9817612133792, angle: -3.88172881837241250 },
    494 => { y: 341.9041564329152, angle: -3.86011272368191900 },
    495 => { y: 341.8269876838443, angle: -3.83840253405522600 },
    496 => { y: 341.7502568255993, angle: -3.81659876208829200 },
    497 => { y: 341.6739657070609, angle: -3.79470192286796100 },
    498 => { y: 341.5981161665146, angle: -3.77271253396137600 },
    499 => { y: 341.5227100316054, angle: -3.75063111540716800 },
    500 => { y: 341.4477491192943, angle: -3.72845818970305250 },
    501 => { y: 341.3732352358145, angle: -3.70619428179648150 },
    502 => { y: 341.2991701766276, angle: -3.68383991907410050 },
    503 => { y: 341.2255557263804, angle: -3.66139563135157650 },
    504 => { y: 341.1523936588621, angle: -3.63886195086151450 },
    505 => { y: 341.0796857369614, angle: -3.61623941224331250 },
    506 => { y: 341.0074337126242, angle: -3.59352855253293750 },
    507 => { y: 340.9356393268108, angle: -3.57072991114996150 },
    508 => { y: 340.8643043094551, angle: -3.54784402988806850 },
    509 => { y: 340.7934303794214, angle: -3.52487145290238950 },
    510 => { y: 340.7230192444645, angle: -3.50181272669960050 },
    511 => { y: 340.6530726011875, angle: -3.47866840012498600 },
    512 => { y: 340.5835921350013, angle: -3.45543902435057250 },
    513 => { y: 340.5145795200839, angle: -3.43212515286517650 },
    514 => { y: 340.4460364193403, angle: -3.40872734146000350 },
    515 => { y: 340.377964484362, angle: -3.38524614821898950 },
    516 => { y: 340.3103653553877, angle: -3.36168213350539750 },
    517 => { y: 340.2432406612633, angle: -3.33803585994920400 },
    518 => { y: 340.176592019403, angle: -3.31430789243596450 },
    519 => { y: 340.1104210357503, angle: -3.29049879809279350 },
    520 => { y: 340.044729304739, angle: -3.26660914627780450 },
    521 => { y: 339.9795184092549, angle: -3.24263950856524750 },
    522 => { y: 339.9147899205982, angle: -3.21859045873453400 },
    523 => { y: 339.8505453984447, angle: -3.19446257275565400 },
    524 => { y: 339.7867863908091, angle: -3.17025642877779450 },
    525 => { y: 339.7235144340071, angle: -3.14597260711447150 },
    526 => { y: 339.6607310526184, angle: -3.12161169023200800 },
    527 => { y: 339.5984377594505, angle: -3.09717426273439700 },
    528 => { y: 339.5366360555018, angle: -3.07266091135149100 },
    529 => { y: 339.4753274299254, angle: -3.04807222492457700 },
    530 => { y: 339.4145133599935, angle: -3.0234087943914600 },
    531 => { y: 339.3541953110615, angle: -2.99867121277529200 },
    532 => { y: 339.294374736533, angle: -2.97386007516852350 },
    533 => { y: 339.2350530778245, angle: -2.94897597871919200 },
    534 => { y: 339.1762317643309, angle: -2.92401952261826900 },
    535 => { y: 339.1179122133909, angle: -2.89899130808255150 },
    536 => { y: 339.0600958302529, angle: -2.87389193834286150 },
    537 => { y: 339.002784008041, angle: -2.84872201862821450 },
    538 => { y: 338.9459781277218, angle: -2.82348215615189350 },
    539 => { y: 338.8896795580708, angle: -2.79817296009604250 },
    540 => { y: 338.8338896556395, angle: -2.77279504159732050 },
    541 => { y: 338.7786097647226, angle: -2.74734901373177600 },
    542 => { y: 338.7238412173261, angle: -2.72183549149979650 },
    543 => { y: 338.6695853331344, angle: -2.69625509181098050 },
    544 => { y: 338.6158434194792, angle: -2.67060843346880850 },
    545 => { y: 338.5626167713077, angle: -2.64489613715579850 },
    546 => { y: 338.5099066711513, angle: -2.61911882541661800 },
    547 => { y: 338.457714389095, angle: -2.59327712264423700 },
    548 => { y: 338.4060411827467, angle: -2.56737165506275350 },
    549 => { y: 338.3548882972065, angle: -2.54140305071270250 },
    550 => { y: 338.3042569650373, angle: -2.51537193943473400 },
    551 => { y: 338.2541484062348, angle: -2.48927895285279550 },
    552 => { y: 338.204563828198, angle: -2.46312472435980100 },
    553 => { y: 338.1555044257004, angle: -2.43690988909939800 },
    554 => { y: 338.1069713808608, angle: -2.41063508395078950 },
    555 => { y: 338.0589658631152, angle: -2.38430094751291650 },
    556 => { y: 338.0114890291887, angle: -2.35790812008559650 },
    557 => { y: 337.9645420230671, angle: -2.33145724365612600 },
    558 => { y: 337.9181259759698, angle: -2.30494896187900050 },
    559 => { y: 337.8722420063222, angle: -2.27838392006267050 },
    560 => { y: 337.8268912197291, angle: -2.25176276514898600 },
    561 => { y: 337.7820747089481, angle: -2.22508614569981150 },
    562 => { y: 337.7377935538626, angle: -2.19835471187662400 },
    563 => { y: 337.6940488214567, angle: -2.1715691154250150 },
    564 => { y: 337.6508415657888, angle: -2.14473000965769550 },
    565 => { y: 337.6081728279663, angle: -2.11783804943588700 },
    566 => { y: 337.566043636121, angle: -2.09089389115234400 },
    567 => { y: 337.5244550053837, angle: -2.06389819271374700 },
    568 => { y: 337.4834079378604, angle: -2.03685161352331100 },
    569 => { y: 337.4429034226072, angle: -2.00975481446205850 },
    570 => { y: 337.4029424356075, angle: -1.98260845787186750 },
    571 => { y: 337.3635259397478, angle: -1.95541320753718900 },
    572 => { y: 337.3246548847949, angle: -1.9281697286666900 },
    573 => { y: 337.2863302073727, angle: -1.90087868787512750 },
    574 => { y: 337.2485528309398, angle: -1.87354075316586850 },
    575 => { y: 337.2113236657671, angle: -1.84615659391121750 },
    576 => { y: 337.1746436089163, angle: -1.81872688083552700 },
    577 => { y: 337.1385135442177, angle: -1.7912522859944100 },
    578 => { y: 337.1029343422493, angle: -1.76373348275971950 },
    579 => { y: 337.0679068603155, angle: -1.7361711457963750 },
    580 => { y: 337.033431942427, angle: -1.70856595104792850 },
    581 => { y: 336.9995104192797, angle: -1.68091857571413250 },
    582 => { y: 336.9661431082354, angle: -1.6532296982348300 },
    583 => { y: 336.9333308133017, angle: -1.62549999826911100 },
    584 => { y: 336.9010743251125, angle: -1.59773015667668100 },
    585 => { y: 336.8693744209095, angle: -1.56992085549903100 },
    586 => { y: 336.8382318645229, angle: -1.54207277794027650 },
    587 => { y: 336.8076474063534, angle: -1.51418660834694250 },
    588 => { y: 336.7776217833538, angle: -1.48626303218968450 },
    589 => { y: 336.7481557190115, angle: -1.45830273604269050 },
    590 => { y: 336.7192499233309, angle: -1.43030640756572250 },
    591 => { y: 336.6909050928165, angle: -1.40227473548213800 },
    592 => { y: 336.6631219104557, angle: -1.37420840956211200 },
    593 => { y: 336.635901045703, angle: -1.34610812060041550 },
    594 => { y: 336.6092431544629, angle: -1.31797456039769300 },
    595 => { y: 336.5831488790753, angle: -1.28980842174027900 },
    596 => { y: 336.5576188482991, angle: -1.26161039838081200 },
    597 => { y: 336.5326536772973, angle: -1.23338118501752900 },
    598 => { y: 336.5082539676222, angle: -1.20512147727422750 },
    599 => { y: 336.4844203072014, angle: -1.17683197168102900 },
    600 => { y: 336.4611532703224, angle: -1.14851336565283050 },
    601 => { y: 336.4384534176203, angle: -1.12016635746998850 },
    602 => { y: 336.4163212960629, angle: -1.09179164625739350 },
    603 => { y: 336.3947574389385, angle: -1.06338993196492850 },
    604 => { y: 336.3737623658426, angle: -1.03496191534632350 },
    605 => { y: 336.3533365826654, angle: -1.00650829793825450 },
    606 => { y: 336.3334805815797, angle: -0.97802978204125450 },
    607 => { y: 336.3141948410293, angle: -0.94952707069830900 },
    608 => { y: 336.2954798257167, angle: -0.92100086767313700 },
    609 => { y: 336.2773359865927, angle: -0.89245187743169950 },
    610 => { y: 336.2597637608453, angle: -0.863880805119700 },
    611 => { y: 336.2427635718888, angle: -0.83528835654288900 },
    612 => { y: 336.2263358293541, angle: -0.80667523814449700 },
    613 => { y: 336.2104809290788, angle: -0.7780421569876100 },
    614 => { y: 336.1951992530969, angle: -0.74938982073054950 },
    615 => { y: 336.180491169631, angle: -0.72071893760833400 },
    616 => { y: 336.1663570330818, angle: -0.6920302164108450 },
    617 => { y: 336.1527971840208, angle: -0.66332436646266950 },
    618 => { y: 336.1398119491817, angle: -0.63460209759964800 },
    619 => { y: 336.1274016414524, angle: -0.60586412015093900 },
    620 => { y: 336.1155665598673, angle: -0.57711114491580100 },
    621 => { y: 336.1043069896007, angle: -0.54834388314276800 },
    622 => { y: 336.0936232019595, angle: -0.51956304650880050 },
    623 => { y: 336.0835154543766, angle: -0.490769347098275150 },
    624 => { y: 336.0739839904049, angle: -0.461963497380673750 },
    625 => { y: 336.0650290397114, angle: -0.433146210190669250 },
    626 => { y: 336.0566508180717, angle: -0.404318198705635400 },
    627 => { y: 336.0488495273643, angle: -0.375480176424844600 },
    628 => { y: 336.0416253555669, angle: -0.346632857148223400 },
    629 => { y: 336.0349784767504, angle: -0.31777695495523450 },
    630 => { y: 336.0289090510759, angle: -0.288913184182182350 },
    631 => { y: 336.0234172247902, angle: -0.26004225940206300 },
    632 => { y: 336.0185031302227, angle: -0.231164895403407700 },
    633 => { y: 336.0141668857815, angle: -0.202281807167125900 },
    634 => { y: 336.0104085959514, angle: -0.173393709846465050 },
    635 => { y: 336.0072283512911, angle: -0.14450131874568300 },
    636 => { y: 336.0046262284304, angle: -0.115605349297575300 },
    637 => { y: 336.0026022900694, angle: -0.086706517041991300 },
    638 => { y: 336.0011565849762, angle: -0.057805537606334200 },
    639 => { y: 336.0002891479859, angle: -0.028903126681082850 },
    640 => { y: 336.0, angle: 0 },
    641 => { y: 336.0002891479859, angle: 0.028903126681082850 },
    642 => { y: 336.0011565849762, angle: 0.057805537606334200 },
    643 => { y: 336.0026022900694, angle: 0.086706517041991300 },
    644 => { y: 336.0046262284304, angle: 0.115605349297575300 },
    645 => { y: 336.0072283512911, angle: 0.14450131874568300 },
    646 => { y: 336.0104085959514, angle: 0.173393709846465050 },
    647 => { y: 336.0141668857815, angle: 0.202281807167125900 },
    648 => { y: 336.0185031302227, angle: 0.231164895403407700 },
    649 => { y: 336.0234172247902, angle: 0.26004225940206300 },
    650 => { y: 336.0289090510759, angle: 0.288913184182182350 },
    651 => { y: 336.0349784767504, angle: 0.31777695495523450 },
    652 => { y: 336.0416253555669, angle: 0.346632857148223400 },
    653 => { y: 336.0488495273643, angle: 0.375480176424844600 },
    654 => { y: 336.0566508180717, angle: 0.404318198705635400 },
    655 => { y: 336.0650290397114, angle: 0.433146210190669250 },
    656 => { y: 336.0739839904049, angle: 0.461963497380673750 },
    657 => { y: 336.0835154543766, angle: 0.490769347098275150 },
    658 => { y: 336.0936232019595, angle: 0.51956304650880050 },
    659 => { y: 336.1043069896007, angle: 0.54834388314276800 },
    660 => { y: 336.1155665598673, angle: 0.57711114491580100 },
    661 => { y: 336.1274016414524, angle: 0.60586412015093900 },
    662 => { y: 336.1398119491817, angle: 0.63460209759964800 },
    663 => { y: 336.1527971840208, angle: 0.66332436646266950 },
    664 => { y: 336.1663570330818, angle: 0.6920302164108450 },
    665 => { y: 336.180491169631, angle: 0.72071893760833400 },
    666 => { y: 336.1951992530969, angle: 0.74938982073054950 },
    667 => { y: 336.2104809290788, angle: 0.7780421569876100 },
    668 => { y: 336.2263358293541, angle: 0.80667523814449700 },
    669 => { y: 336.2427635718888, angle: 0.83528835654288900 },
    670 => { y: 336.2597637608453, angle: 0.863880805119700 },
    671 => { y: 336.2773359865927, angle: 0.89245187743169950 },
    672 => { y: 336.2954798257167, angle: 0.92100086767313700 },
    673 => { y: 336.3141948410293, angle: 0.94952707069816700 },
    674 => { y: 336.3334805815797, angle: 0.97802978204125450 },
    675 => { y: 336.3533365826654, angle: 1.00650829793811250 },
    676 => { y: 336.3737623658426, angle: 1.03496191534632350 },
    677 => { y: 336.3947574389385, angle: 1.06338993196492850 },
    678 => { y: 336.4163212960629, angle: 1.09179164625739350 },
    679 => { y: 336.4384534176203, angle: 1.12016635746998850 },
    680 => { y: 336.4611532703224, angle: 1.14851336565283050 },
    681 => { y: 336.4844203072014, angle: 1.17683197168088650 },
    682 => { y: 336.5082539676222, angle: 1.20512147727422750 },
    683 => { y: 336.5326536772972, angle: 1.23338118501752900 },
    684 => { y: 336.5576188482991, angle: 1.26161039838081200 },
    685 => { y: 336.5831488790753, angle: 1.28980842174027900 },
    686 => { y: 336.6092431544629, angle: 1.31797456039755100 },
    687 => { y: 336.635901045703, angle: 1.34610812060041550 },
    688 => { y: 336.6631219104557, angle: 1.37420840956211200 },
    689 => { y: 336.6909050928165, angle: 1.40227473548213800 },
    690 => { y: 336.7192499233309, angle: 1.43030640756572250 },
    691 => { y: 336.7481557190114, angle: 1.45830273604269050 },
    692 => { y: 336.7776217833538, angle: 1.48626303218968450 },
    693 => { y: 336.8076474063534, angle: 1.51418660834708450 },
    694 => { y: 336.8382318645229, angle: 1.54207277794027650 },
    695 => { y: 336.8693744209095, angle: 1.56992085549917300 },
    696 => { y: 336.9010743251125, angle: 1.59773015667668100 },
    697 => { y: 336.9333308133017, angle: 1.62549999826911100 },
    698 => { y: 336.9661431082354, angle: 1.6532296982348300 },
    699 => { y: 336.9995104192797, angle: 1.68091857571413250 },
    700 => { y: 337.033431942427, angle: 1.70856595104792850 },
    701 => { y: 337.0679068603155, angle: 1.73617114579651700 },
    702 => { y: 337.1029343422493, angle: 1.76373348275971950 },
    703 => { y: 337.1385135442177, angle: 1.7912522859944100 },
    704 => { y: 337.1746436089163, angle: 1.81872688083552700 },
    705 => { y: 337.2113236657671, angle: 1.84615659391121750 },
    706 => { y: 337.2485528309398, angle: 1.87354075316601050 },
    707 => { y: 337.2863302073727, angle: 1.90087868787512750 },
    708 => { y: 337.3246548847949, angle: 1.9281697286666900 },
    709 => { y: 337.3635259397478, angle: 1.95541320753718900 },
    710 => { y: 337.4029424356075, angle: 1.98260845787186750 },
    711 => { y: 337.4429034226072, angle: 2.00975481446205850 },
    712 => { y: 337.4834079378604, angle: 2.03685161352331100 },
    713 => { y: 337.5244550053837, angle: 2.06389819271374700 },
    714 => { y: 337.566043636121, angle: 2.09089389115234400 },
    715 => { y: 337.6081728279663, angle: 2.11783804943588700 },
    716 => { y: 337.6508415657888, angle: 2.14473000965769550 },
    717 => { y: 337.6940488214567, angle: 2.1715691154250150 },
    718 => { y: 337.7377935538626, angle: 2.19835471187662400 },
    719 => { y: 337.7820747089481, angle: 2.22508614569981150 },
    720 => { y: 337.8268912197291, angle: 2.25176276514898600 },
    721 => { y: 337.8722420063222, angle: 2.27838392006267050 },
    722 => { y: 337.9181259759698, angle: 2.30494896187900050 },
    723 => { y: 337.9645420230671, angle: 2.33145724365612600 },
    724 => { y: 338.0114890291887, angle: 2.35790812008559650 },
    725 => { y: 338.0589658631152, angle: 2.38430094751291650 },
    726 => { y: 338.1069713808608, angle: 2.41063508395078950 },
    727 => { y: 338.1555044257004, angle: 2.43690988909939800 },
    728 => { y: 338.204563828198, angle: 2.46312472435980100 },
    729 => { y: 338.2541484062348, angle: 2.48927895285279550 },
    730 => { y: 338.3042569650373, angle: 2.51537193943473400 },
    731 => { y: 338.3548882972065, angle: 2.54140305071270250 },
    732 => { y: 338.4060411827467, angle: 2.56737165506261150 },
    733 => { y: 338.457714389095, angle: 2.59327712264423700 },
    734 => { y: 338.5099066711513, angle: 2.61911882541661800 },
    735 => { y: 338.5626167713077, angle: 2.64489613715579850 },
    736 => { y: 338.6158434194792, angle: 2.67060843346880850 },
    737 => { y: 338.6695853331344, angle: 2.69625509181098050 },
    738 => { y: 338.7238412173261, angle: 2.72183549149979650 },
    739 => { y: 338.7786097647226, angle: 2.74734901373163400 },
    740 => { y: 338.8338896556395, angle: 2.77279504159732050 },
    741 => { y: 338.8896795580708, angle: 2.79817296009604250 },
    742 => { y: 338.9459781277218, angle: 2.82348215615189350 },
    743 => { y: 339.002784008041, angle: 2.84872201862821450 },
    744 => { y: 339.0600958302529, angle: 2.87389193834286150 },
    745 => { y: 339.1179122133909, angle: 2.89899130808255150 },
    746 => { y: 339.1762317643309, angle: 2.92401952261826900 },
    747 => { y: 339.2350530778245, angle: 2.94897597871919200 },
    748 => { y: 339.294374736533, angle: 2.97386007516852350 },
    749 => { y: 339.3541953110615, angle: 2.99867121277529200 },
    750 => { y: 339.4145133599935, angle: 3.0234087943914600 },
    751 => { y: 339.4753274299254, angle: 3.04807222492457700 },
    752 => { y: 339.5366360555018, angle: 3.07266091135163250 },
    753 => { y: 339.5984377594505, angle: 3.09717426273439700 },
    754 => { y: 339.6607310526184, angle: 3.12161169023200800 },
    755 => { y: 339.7235144340071, angle: 3.14597260711447150 },
    756 => { y: 339.7867863908091, angle: 3.17025642877779450 },
    757 => { y: 339.8505453984447, angle: 3.19446257275565400 },
    758 => { y: 339.9147899205982, angle: 3.218590458734250 },
    759 => { y: 339.9795184092549, angle: 3.24263950856538900 },
    760 => { y: 340.044729304739, angle: 3.26660914627780450 },
    761 => { y: 340.1104210357503, angle: 3.29049879809279350 },
    762 => { y: 340.176592019403, angle: 3.31430789243582300 },
    763 => { y: 340.2432406612633, angle: 3.33803585994920400 },
    764 => { y: 340.3103653553877, angle: 3.36168213350539750 },
    765 => { y: 340.377964484362, angle: 3.38524614821898950 },
    766 => { y: 340.4460364193403, angle: 3.40872734146000350 },
    767 => { y: 340.5145795200839, angle: 3.43212515286517650 },
    768 => { y: 340.5835921350012, angle: 3.45543902435057250 },
    769 => { y: 340.6530726011875, angle: 3.47866840012498600 },
    770 => { y: 340.7230192444645, angle: 3.50181272669960050 },
    771 => { y: 340.7934303794214, angle: 3.52487145290238950 },
    772 => { y: 340.864304309455, angle: 3.54784402988806850 },
    773 => { y: 340.9356393268108, angle: 3.57072991114996150 },
    774 => { y: 341.0074337126242, angle: 3.59352855253293750 },
    775 => { y: 341.0796857369614, angle: 3.61623941224331250 },
    776 => { y: 341.1523936588621, angle: 3.63886195086151450 },
    777 => { y: 341.2255557263804, angle: 3.66139563135157650 },
    778 => { y: 341.2991701766276, angle: 3.68383991907438400 },
    779 => { y: 341.3732352358145, angle: 3.70619428179648150 },
    780 => { y: 341.4477491192943, angle: 3.72845818970305250 },
    781 => { y: 341.5227100316054, angle: 3.75063111540716800 },
    782 => { y: 341.5981161665146, angle: 3.77271253396151750 },
    783 => { y: 341.6739657070609, angle: 3.79470192286781950 },
    784 => { y: 341.7502568255993, angle: 3.81659876208829200 },
    785 => { y: 341.8269876838443, angle: 3.83840253405508450 },
    786 => { y: 341.9041564329152, angle: 3.86011272368191900 },
    787 => { y: 341.9817612133792, angle: 3.88172881837241250 },
    788 => { y: 342.0598001552977, angle: 3.90325030803146550 },
    789 => { y: 342.1382713782704, angle: 3.92467668507417650 },
    790 => { y: 342.217172991481, angle: 3.94600744443655350 },
    791 => { y: 342.2965030937425, angle: 3.96724208358446300 },
    792 => { y: 342.3762597735435, angle: 3.98838010252351600 },
    793 => { y: 342.4564411090936, angle: 4.00942100380820350 },
    794 => { y: 342.5370451683702, angle: 4.03036429255180800 },
    795 => { y: 342.6180700091647, angle: 4.05120947643557900 },
    796 => { y: 342.69951367913, angle: 4.07195606571642400 },
    797 => { y: 342.7813742158262, angle: 4.09260357323851600 },
    798 => { y: 342.8636496467696, angle: 4.1131515144397600 },
    799 => { y: 342.9463379894786, angle: 4.13359940736231100 },
    800 => { y: 343.0294372515228, angle: 4.15394677266021450 },
    801 => { y: 343.1129454305702, angle: 4.17419313360869200 },
    802 => { y: 343.1968605144355, angle: 4.19433801611169050 },
    803 => { y: 343.2811804811288, angle: 4.21438094871178350 },
    804 => { y: 343.3659032989047, angle: 4.23432146259705700 },
    805 => { y: 343.4510269263104, angle: 4.25415909161035700 },
    806 => { y: 343.5365493122354, angle: 4.27389337225580400 },
    807 => { y: 343.6224683959609, angle: 4.29352384370880200 },
    808 => { y: 343.7087821072094, angle: 4.31305004782260850 },
    809 => { y: 343.7954883661947, angle: 4.3324715291361350 },
    810 => { y: 343.8825850836716, angle: 4.35178783488241800 },
    811 => { y: 343.9700701609868, angle: 4.37099851499492550 },
    812 => { y: 344.0579414901292, angle: 4.3901031221165050 },
    813 => { y: 344.1461969537806, angle: 4.40910121160590700 },
    814 => { y: 344.234834425367, angle: 4.4279923415446750 },
    815 => { y: 344.3238517691094, angle: 4.44677607274500250 },
    816 => { y: 344.4132468400756, angle: 4.46545196875711900 },
    817 => { y: 344.503017484232, angle: 4.48401959587523950 },
    818 => { y: 344.5931615384952, angle: 4.50247852314531100 },
    819 => { y: 344.683676830784, angle: 4.52082832237116550 },
    820 => { y: 344.7745611800725, angle: 4.53906856812206650 },
    821 => { y: 344.8658123964416, angle: 4.55719883773809550 },
    822 => { y: 344.9574282811327, angle: 4.57521871133805150 },
    823 => { y: 345.0494066266, angle: 4.59312777182464350 },
    824 => { y: 345.141745216564, angle: 4.61092560489148200 },
    825 => { y: 345.2344418260649, angle: 4.6286117990293400 },
    826 => { y: 345.3274942215164, angle: 4.6461859455316850 },
    827 => { y: 345.4209001607589, angle: 4.66364763850173250 },
    828 => { y: 345.5146573931143, angle: 4.68099647485735950 },
    829 => { y: 345.6087636594395, angle: 4.69823205433796700 },
    830 => { y: 345.7032166921816, angle: 4.71535397950892800 },
    831 => { y: 345.7980142154317, angle: 4.73236185576882400 },
    832 => { y: 345.8931539449806, angle: 4.74925529135427200 },
    833 => { y: 345.9886335883731, angle: 4.76603389734486700 },
    834 => { y: 346.0844508449637, angle: 4.78269728767021900 },
    835 => { y: 346.1806034059717, angle: 4.79924507911387450 },
    836 => { y: 346.2770889545373, angle: 4.81567689131848800 },
    837 => { y: 346.3739051657769, angle: 4.83199234679280300 },
    838 => { y: 346.4710497068396, angle: 4.84819107091425900 },
    839 => { y: 346.5685202369629, angle: 4.86427269193650550 },
    840 => { y: 346.6663144075296, angle: 4.8802368409922600 },
    841 => { y: 346.7644298621239, angle: 4.89608315209939200 },
    842 => { y: 346.8628642365889, angle: 4.91181126216501900 },
    843 => { y: 346.9616151590826, angle: 4.92742081099100400 },
    844 => { y: 347.060680250136, angle: 4.94291144127789650 },
    845 => { y: 347.1600571227097, angle: 4.95828279862956100 },
    846 => { y: 347.2597433822518, angle: 4.97353453155808550 },
    847 => { y: 347.3597366267556, angle: 4.9886662914876950 },
    848 => { y: 347.4600344468172, angle: 5.0036777327592250 },
    849 => { y: 347.560634425694, angle: 5.0185685126345800 },
    850 => { y: 347.6615341393627, angle: 5.0333382913005100 },
    851 => { y: 347.7627311565773, angle: 5.0479867318730450 },
    852 => { y: 347.8642230389283, angle: 5.0625135004014100 },
    853 => { y: 347.9660073409015, angle: 5.0769182658720450 },
    854 => { y: 348.0680816099363, angle: 5.0912007002120850 },
    855 => { y: 348.1704433864852, angle: 5.1053604782938100 },
    856 => { y: 348.2730902040731, angle: 5.1193972779386800 },
    857 => { y: 348.3760195893566, angle: 5.1333107799189950 },
    858 => { y: 348.4792290621837, angle: 5.1471006679644600 },
    859 => { y: 348.5827161356535, angle: 5.1607666287629850 },
    860 => { y: 348.6864783161761, angle: 5.1743083519663100 },
    861 => { y: 348.7905131035325, angle: 5.1877255301922250 },
    862 => { y: 348.8948179909356, angle: 5.2010178590283450 },
    863 => { y: 348.9993904650895, angle: 5.2141850370346550 },
    864 => { y: 349.1042280062509, angle: 5.2272267657480050 },
    865 => { y: 349.2093280882894, angle: 5.2401427496843900 },
    866 => { y: 349.3146881787488, angle: 5.2529326963427650 },
    867 => { y: 349.4203057389074, angle: 5.2655963162067650 },
    868 => { y: 349.5261782238398, angle: 5.2781333227490050 },
    869 => { y: 349.6323030824781, angle: 5.2905434324333750 },
    870 => { y: 349.7386777576732, angle: 5.3028263647183650 },
    871 => { y: 349.8452996862565, angle: 5.3149818420596950 },
    872 => { y: 349.9521662991017, angle: 5.3270095899118400 },
    873 => { y: 350.0592750211866, angle: 5.3389093367333750 },
    874 => { y: 350.1666232716553, angle: 5.3506808139872550 },
    875 => { y: 350.2742084638802, angle: 5.3623237561440750 },
    876 => { y: 350.3820280055246, angle: 5.3738379006849700 },
    877 => { y: 350.4900792986048, angle: 5.3852229881041850 },
    878 => { y: 350.5983597395531, angle: 5.3964787619111600 },
    879 => { y: 350.70686671928, angle: 5.4076049686321950 },
    880 => { y: 350.8155976232378, angle: 5.4186013578143900 },
    881 => { y: 350.924549831483, angle: 5.4294676820266450 },
    882 => { y: 351.0337207187396, angle: 5.440203696862700 },
    883 => { y: 351.1431076544624, angle: 5.4508091609427350 },
    884 => { y: 351.2527080029004, angle: 5.4612838359151800 },
    885 => { y: 351.3625191231603, angle: 5.471627486460650 },
    886 => { y: 351.47253836927, angle: 5.4818398802907050 },
    887 => { y: 351.5827630902426, angle: 5.4919207881538050 },
    888 => { y: 351.6931906301402, angle: 5.5018699838338700 },
    889 => { y: 351.8038183281375, angle: 5.5116872441541900 },
    890 => { y: 351.9146435185867, angle: 5.5213723489784150 },
    891 => { y: 352.025663531081, angle: 5.5309250812124300 },
    892 => { y: 352.1368756905193, angle: 5.540345226807400 },
    893 => { y: 352.2482773171707, angle: 5.5496325747588950 },
    894 => { y: 352.3598657267387, angle: 5.5587869171106950 },
    895 => { y: 352.4716382304266, angle: 5.5678080489566700 },
    896 => { y: 352.5835921350012, angle: 5.5766957684404350 },
    897 => { y: 352.6957247428589, angle: 5.5854498767585850 },
    898 => { y: 352.8080333520899, angle: 5.5940701781616900 },
    899 => { y: 352.9205152565433, angle: 5.6025564799561800 },
    900 => { y: 353.0331677458929, angle: 5.6109085925044550 },
    901 => { y: 353.145988105702, angle: 5.6191263292285450 },
    902 => { y: 353.258973617489, angle: 5.6272095066088900 },
    903 => { y: 353.3721215587927, angle: 5.6351579441883600 },
    904 => { y: 353.4854292032382, angle: 5.6429714645716850 },
    905 => { y: 353.5988938206024, angle: 5.6506498934268900 },
    906 => { y: 353.7125126768799, angle: 5.658193059488350 },
    907 => { y: 353.8262830343486, angle: 5.6656007945546350 },
    908 => { y: 353.9402021516362, angle: 5.6728729334934850 },
    909 => { y: 354.0542672837856, angle: 5.680009314240600 },
    910 => { y: 354.1684756823216, angle: 5.6870097778010550 },
    911 => { y: 354.2828245953169, angle: 5.6938741682510100 },
    912 => { y: 354.3973112674582, angle: 5.7006023327377700 },
    913 => { y: 354.5119329401131, angle: 5.7071941214827650 },
    914 => { y: 354.626686851396, angle: 5.7136493877802900 },
    915 => { y: 354.7415702362351, angle: 5.7199679879997250 },
    916 => { y: 354.8565803264388, angle: 5.726149781585950 },
    917 => { y: 354.9717143507623, angle: 5.73219463106150 },
    918 => { y: 355.0869695349749, angle: 5.7381024020248600 },
    919 => { y: 355.202343101926, angle: 5.7438729631545300 },
    920 => { y: 355.3178322716129, angle: 5.7495061862077200 },
    921 => { y: 355.4334342612472, angle: 5.7550019460212900 },
    922 => { y: 355.5491462853218, angle: 5.7603601205136350 },
    923 => { y: 355.6649655556787, angle: 5.7655805906840650 },
    924 => { y: 355.7808892815755, angle: 5.7706632406151950 },
    925 => { y: 355.8969146697528, angle: 5.7756079574720450 },
    926 => { y: 356.0130389245016, angle: 5.7804146315034050 },
    927 => { y: 356.1292592477309, angle: 5.7850831560429900 },
    928 => { y: 356.2455728390344, angle: 5.7896134275091350 },
    929 => { y: 356.361976895759, angle: 5.7940053454059100 },
    930 => { y: 356.4784686130713, angle: 5.7982588123239050 },
    931 => { y: 356.5950451840259, angle: 5.8023737339403250 },
    932 => { y: 356.7117037996328, angle: 5.8063500190202050 },
    933 => { y: 356.8284416489249, angle: 5.8101875794157650 },
    934 => { y: 356.9452559190261, angle: 5.8138863300687250 },
    935 => { y: 357.0621437952188, angle: 5.8174461890085200 },
    936 => { y: 357.1791024610119, angle: 5.8208670773552800 },
    937 => { y: 357.2961290982084, angle: 5.8241489193177750 },
    938 => { y: 357.4132208869738, angle: 5.82729164219650 },
    939 => { y: 357.5303750059033, angle: 5.8302951763810350 },
    940 => { y: 357.6475886320906, angle: 5.8331594553531150 },
    941 => { y: 357.7648589411952, angle: 5.8358844156855250 },
    942 => { y: 357.8821831075111, angle: 5.8384699970433250 },
    943 => { y: 357.9995583040345, angle: 5.8409161421832950 },
    944 => { y: 358.1169817025317, angle: 5.843222796954700 },
    945 => { y: 358.234450473608, angle: 5.8453899102997300 },
    946 => { y: 358.351961786775, angle: 5.8474174342532750 },
    947 => { y: 358.4695128105195, angle: 5.8493053239441550 },
    948 => { y: 358.5871007123715, angle: 5.8510535375939200 },
    949 => { y: 358.7047226589719, angle: 5.8526620365186450 },
    950 => { y: 358.822375816142, angle: 5.8541307851281200 },
    951 => { y: 358.9400573489503, angle: 5.8554597509262150 },
    952 => { y: 359.0577644217823, angle: 5.8566489045109350 },
    953 => { y: 359.1754941984076, angle: 5.8576982195751700 },
    954 => { y: 359.2932438420489, angle: 5.8586076729064450 },
    955 => { y: 359.4110105154501, angle: 5.8593772443868600 },
    956 => { y: 359.5287913809449, angle: 5.86000691699350 },
    957 => { y: 359.646583600525, angle: 5.8604966767980850 },
    958 => { y: 359.7643843359084, angle: 5.8608465129677850 },
    959 => { y: 359.882190748608, angle: 5.8610564177647400 },
    960 => { y: 360.0, angle: 5.8611263865462800 },
    961 => { y: 360.117809251392, angle: 5.8610564177648800 },
    962 => { y: 360.2356156640916, angle: 5.8608465129677850 },
    963 => { y: 360.353416399475, angle: 5.8604966767980850 },
    964 => { y: 360.4712086190551, angle: 5.86000691699350 },
    965 => { y: 360.5889894845499, angle: 5.8593772443868600 },
    966 => { y: 360.7067561579511, angle: 5.8586076729064450 },
    967 => { y: 360.8245058015924, angle: 5.8576982195751700 },
    968 => { y: 360.9422355782177, angle: 5.8566489045109350 },
    969 => { y: 361.0599426510496, angle: 5.8554597509262150 },
    970 => { y: 361.177624183858, angle: 5.8541307851281200 },
    971 => { y: 361.2952773410281, angle: 5.8526620365186450 },
    972 => { y: 361.4128992876285, angle: 5.8510535375939200 },
    973 => { y: 361.5304871894804, angle: 5.8493053239441550 },
    974 => { y: 361.648038213225, angle: 5.8474174342532750 },
    975 => { y: 361.765549526392, angle: 5.8453899102997300 },
    976 => { y: 361.8830182974683, angle: 5.843222796954700 },
    977 => { y: 362.0004416959655, angle: 5.8409161421834350 },
    978 => { y: 362.1178168924889, angle: 5.8384699970433250 },
    979 => { y: 362.2351410588048, angle: 5.8358844156856650 },
    980 => { y: 362.3524113679094, angle: 5.8331594553531150 },
    981 => { y: 362.4696249940967, angle: 5.8302951763810350 },
    982 => { y: 362.5867791130262, angle: 5.82729164219650 },
    983 => { y: 362.7038709017916, angle: 5.8241489193179150 },
    984 => { y: 362.8208975389881, angle: 5.8208670773552800 },
    985 => { y: 362.9378562047812, angle: 5.8174461890085200 },
    986 => { y: 363.0547440809739, angle: 5.8138863300687250 },
    987 => { y: 363.1715583510751, angle: 5.8101875794157650 },
    988 => { y: 363.2882962003672, angle: 5.8063500190202050 },
    989 => { y: 363.4049548159741, angle: 5.8023737339403250 },
    990 => { y: 363.5215313869287, angle: 5.7982588123239050 },
    991 => { y: 363.638023104241, angle: 5.7940053454059100 },
    992 => { y: 363.7544271609656, angle: 5.7896134275089950 },
    993 => { y: 363.8707407522691, angle: 5.7850831560429900 },
    994 => { y: 363.9869610754984, angle: 5.7804146315034050 },
    995 => { y: 364.1030853302472, angle: 5.7756079574720450 },
    996 => { y: 364.2191107184245, angle: 5.7706632406151950 },
    997 => { y: 364.3350344443213, angle: 5.7655805906840650 },
    998 => { y: 364.4508537146782, angle: 5.7603601205134950 },
    999 => { y: 364.5665657387528, angle: 5.7550019460212900 },
    1000 => { y: 364.6821677283871, angle: 5.7495061862075800 },
    1001 => { y: 364.797656898074, angle: 5.7438729631545300 },
    1002 => { y: 364.9130304650251, angle: 5.7381024020248600 },
    1003 => { y: 365.0282856492377, angle: 5.7321946310613600 },
    1004 => { y: 365.1434196735612, angle: 5.726149781585950 },
    1005 => { y: 365.2584297637649, angle: 5.7199679879997250 },
    1006 => { y: 365.373313148604, angle: 5.7136493877802900 },
    1007 => { y: 365.4880670598869, angle: 5.7071941214827650 },
    1008 => { y: 365.6026887325417, angle: 5.7006023327377700 },
    1009 => { y: 365.7171754046831, angle: 5.6938741682510100 },
    1010 => { y: 365.8315243176783, angle: 5.6870097778010550 },
    1011 => { y: 365.9457327162144, angle: 5.680009314240600 },
    1012 => { y: 366.0597978483638, angle: 5.6728729334936250 },
    1013 => { y: 366.1737169656514, angle: 5.6656007945546350 },
    1014 => { y: 366.2874873231201, angle: 5.6581930594880700 },
    1015 => { y: 366.4011061793976, angle: 5.6506498934268900 },
    1016 => { y: 366.5145707967618, angle: 5.6429714645715450 },
    1017 => { y: 366.6278784412073, angle: 5.6351579441883600 },
    1018 => { y: 366.741026382511, angle: 5.6272095066088900 },
    1019 => { y: 366.854011894298, angle: 5.6191263292285450 },
    1020 => { y: 366.9668322541071, angle: 5.6109085925045950 },
    1021 => { y: 367.0794847434567, angle: 5.6025564799561800 },
    1022 => { y: 367.1919666479101, angle: 5.5940701781616900 },
    1023 => { y: 367.3042752571411, angle: 5.5854498767587250 },
    1024 => { y: 367.4164078649987, angle: 5.5766957684402950 },
    1025 => { y: 367.5283617695734, angle: 5.5678080489566700 },
    1026 => { y: 367.6401342732612, angle: 5.5587869171106950 },
    1027 => { y: 367.7517226828293, angle: 5.5496325747587550 },
    1028 => { y: 367.8631243094806, angle: 5.5403452268072600 },
    1029 => { y: 367.974336468919, angle: 5.5309250812124300 },
    1030 => { y: 368.0853564814133, angle: 5.5213723489784150 },
    1031 => { y: 368.1961816718625, angle: 5.5116872441541900 },
    1032 => { y: 368.3068093698598, angle: 5.5018699838338700 },
    1033 => { y: 368.4172369097574, angle: 5.4919207881538050 },
    1034 => { y: 368.5274616307299, angle: 5.4818398802909850 },
    1035 => { y: 368.6374808768397, angle: 5.4716274864605100 },
    1036 => { y: 368.7472919970996, angle: 5.4612838359153200 },
    1037 => { y: 368.8568923455376, angle: 5.4508091609427350 },
    1038 => { y: 368.9662792812604, angle: 5.4402036968628400 },
    1039 => { y: 369.075450168517, angle: 5.4294676820266450 },
    1040 => { y: 369.1844023767622, angle: 5.4186013578143900 },
    1041 => { y: 369.29313328072, angle: 5.4076049686321950 },
    1042 => { y: 369.4016402604469, angle: 5.3964787619111600 },
    1043 => { y: 369.5099207013952, angle: 5.3852229881040450 },
    1044 => { y: 369.6179719944754, angle: 5.3738379006851100 },
    1045 => { y: 369.7257915361197, angle: 5.3623237561439350 },
    1046 => { y: 369.8333767283447, angle: 5.3506808139872550 },
    1047 => { y: 369.9407249788134, angle: 5.3389093367335200 },
    1048 => { y: 370.0478337008983, angle: 5.3270095899119850 },
    1049 => { y: 370.1547003137435, angle: 5.3149818420596950 },
    1050 => { y: 370.2613222423268, angle: 5.3028263647183650 },
    1051 => { y: 370.3676969175219, angle: 5.2905434324333750 },
    1052 => { y: 370.4738217761602, angle: 5.2781333227490050 },
    1053 => { y: 370.5796942610926, angle: 5.2655963162067650 },
    1054 => { y: 370.6853118212512, angle: 5.2529326963427650 },
    1055 => { y: 370.7906719117105, angle: 5.2401427496845300 },
    1056 => { y: 370.8957719937491, angle: 5.2272267657480050 },
    1057 => { y: 371.0006095349105, angle: 5.2141850370346550 },
    1058 => { y: 371.1051820090644, angle: 5.2010178590282050 },
    1059 => { y: 371.2094868964675, angle: 5.1877255301922250 },
    1060 => { y: 371.3135216838239, angle: 5.1743083519663100 },
    1061 => { y: 371.4172838643465, angle: 5.1607666287629850 },
    1062 => { y: 371.5207709378163, angle: 5.1471006679644600 },
    1063 => { y: 371.6239804106434, angle: 5.1333107799191350 },
    1064 => { y: 371.7269097959269, angle: 5.1193972779385400 },
    1065 => { y: 371.8295566135148, angle: 5.105360478293950 },
    1066 => { y: 371.9319183900637, angle: 5.0912007002120850 },
    1067 => { y: 372.0339926590985, angle: 5.0769182658719050 },
    1068 => { y: 372.1357769610716, angle: 5.0625135004014100 },
    1069 => { y: 372.2372688434227, angle: 5.0479867318730450 },
    1070 => { y: 372.3384658606373, angle: 5.0333382913005100 },
    1071 => { y: 372.439365574306, angle: 5.0185685126345800 },
    1072 => { y: 372.5399655531828, angle: 5.0036777327592250 },
    1073 => { y: 372.6402633732444, angle: 4.9886662914876950 },
    1074 => { y: 372.7402566177482, angle: 4.97353453155808550 },
    1075 => { y: 372.8399428772903, angle: 4.95828279862956100 },
    1076 => { y: 372.939319749864, angle: 4.94291144127789650 },
    1077 => { y: 373.0383848409173, angle: 4.92742081099100400 },
    1078 => { y: 373.1371357634111, angle: 4.91181126216515900 },
    1079 => { y: 373.2355701378761, angle: 4.89608315209925150 },
    1080 => { y: 373.3336855924704, angle: 4.8802368409922600 },
    1081 => { y: 373.4314797630371, angle: 4.86427269193650550 },
    1082 => { y: 373.5289502931604, angle: 4.84819107091425900 },
    1083 => { y: 373.6260948342231, angle: 4.83199234679280300 },
    1084 => { y: 373.7229110454627, angle: 4.81567689131862850 },
    1085 => { y: 373.8193965940283, angle: 4.79924507911387450 },
    1086 => { y: 373.9155491550363, angle: 4.78269728767021900 },
    1087 => { y: 374.0113664116269, angle: 4.76603389734500800 },
    1088 => { y: 374.1068460550194, angle: 4.74925529135427200 },
    1089 => { y: 374.2019857845682, angle: 4.73236185576882400 },
    1090 => { y: 374.2967833078184, angle: 4.71535397950878700 },
    1091 => { y: 374.3912363405605, angle: 4.69823205433796700 },
    1092 => { y: 374.4853426068857, angle: 4.68099647485735950 },
    1093 => { y: 374.5790998392411, angle: 4.66364763850173250 },
    1094 => { y: 374.6725057784836, angle: 4.6461859455316850 },
    1095 => { y: 374.7655581739351, angle: 4.6286117990293400 },
    1096 => { y: 374.858254783436, angle: 4.61092560489148200 },
    1097 => { y: 374.9505933734, angle: 4.59312777182464350 },
    1098 => { y: 375.0425717188673, angle: 4.57521871133805150 },
    1099 => { y: 375.1341876035584, angle: 4.55719883773823600 },
    1100 => { y: 375.2254388199274, angle: 4.53906856812206650 },
    1101 => { y: 375.316323169216, angle: 4.52082832237116550 },
    1102 => { y: 375.4068384615048, angle: 4.50247852314531100 },
    1103 => { y: 375.496982515768, angle: 4.48401959587523950 },
    1104 => { y: 375.5867531599244, angle: 4.46545196875711900 },
    1105 => { y: 375.6761482308906, angle: 4.44677607274500250 },
    1106 => { y: 375.765165574633, angle: 4.4279923415446750 },
    1107 => { y: 375.8538030462194, angle: 4.40910121160590700 },
    1108 => { y: 375.9420585098708, angle: 4.3901031221165050 },
    1109 => { y: 376.0299298390132, angle: 4.37099851499492550 },
    1110 => { y: 376.1174149163284, angle: 4.35178783488255950 },
    1111 => { y: 376.2045116338053, angle: 4.3324715291361350 },
    1112 => { y: 376.2912178927906, angle: 4.31305004782260850 },
    1113 => { y: 376.3775316040391, angle: 4.29352384370880200 },
    1114 => { y: 376.4634506877646, angle: 4.27389337225580400 },
    1115 => { y: 376.5489730736896, angle: 4.25415909161021550 },
    1116 => { y: 376.6340967010953, angle: 4.23432146259705700 },
    1117 => { y: 376.7188195188712, angle: 4.21438094871164300 },
    1118 => { y: 376.8031394855645, angle: 4.19433801611169050 },
    1119 => { y: 376.8870545694298, angle: 4.17419313360869200 },
    1120 => { y: 376.9705627484772, angle: 4.15394677266021450 },
    1121 => { y: 377.0536620105214, angle: 4.13359940736231100 },
    1122 => { y: 377.1363503532304, angle: 4.1131515144397600 },
    1123 => { y: 377.2186257841738, angle: 4.09260357323851600 },
    1124 => { y: 377.30048632087, angle: 4.07195606571642400 },
    1125 => { y: 377.3819299908352, angle: 4.05120947643557900 },
    1126 => { y: 377.4629548316298, angle: 4.03036429255180800 },
    1127 => { y: 377.5435588909064, angle: 4.00942100380820350 },
    1128 => { y: 377.6237402264565, angle: 3.98838010252351600 },
    1129 => { y: 377.7034969062575, angle: 3.96724208358446300 },
    1130 => { y: 377.782827008519, angle: 3.94600744443655350 },
    1131 => { y: 377.8617286217296, angle: 3.92467668507417650 },
    1132 => { y: 377.9401998447023, angle: 3.90325030803146550 },
    1133 => { y: 378.0182387866208, angle: 3.88172881837241250 },
    1134 => { y: 378.0958435670848, angle: 3.86011272368191900 },
    1135 => { y: 378.1730123161557, angle: 3.83840253405522600 },
    1136 => { y: 378.2497431744007, angle: 3.81659876208829200 },
    1137 => { y: 378.3260342929391, angle: 3.79470192286796100 },
    1138 => { y: 378.4018838334854, angle: 3.77271253396137600 },
    1139 => { y: 378.4772899683946, angle: 3.75063111540716800 },
    1140 => { y: 378.5522508807057, angle: 3.72845818970305250 },
    1141 => { y: 378.6267647641855, angle: 3.70619428179648150 },
    1142 => { y: 378.7008298233724, angle: 3.68383991907410050 },
    1143 => { y: 378.7744442736196, angle: 3.66139563135157650 },
    1144 => { y: 378.8476063411379, angle: 3.63886195086151450 },
    1145 => { y: 378.9203142630386, angle: 3.61623941224331250 },
    1146 => { y: 378.9925662873758, angle: 3.59352855253293750 },
    1147 => { y: 379.0643606731892, angle: 3.57072991114996150 },
    1148 => { y: 379.1356956905449, angle: 3.54784402988806850 },
    1149 => { y: 379.2065696205786, angle: 3.52487145290238950 },
    1150 => { y: 379.2769807555355, angle: 3.50181272669960050 },
    1151 => { y: 379.3469273988125, angle: 3.47866840012498600 },
    1152 => { y: 379.4164078649987, angle: 3.45543902435057250 },
    1153 => { y: 379.4854204799161, angle: 3.43212515286517650 },
    1154 => { y: 379.5539635806597, angle: 3.40872734146000350 },
    1155 => { y: 379.622035515638, angle: 3.38524614821898950 },
    1156 => { y: 379.6896346446123, angle: 3.36168213350539750 },
    1157 => { y: 379.7567593387367, angle: 3.33803585994920400 },
    1158 => { y: 379.823407980597, angle: 3.31430789243596450 },
    1159 => { y: 379.8895789642497, angle: 3.29049879809279350 },
    1160 => { y: 379.955270695261, angle: 3.26660914627780450 },
    1161 => { y: 380.0204815907451, angle: 3.24263950856524750 },
    1162 => { y: 380.0852100794018, angle: 3.21859045873453400 },
    1163 => { y: 380.1494546015553, angle: 3.19446257275565400 },
    1164 => { y: 380.2132136091909, angle: 3.17025642877779450 },
    1165 => { y: 380.2764855659929, angle: 3.14597260711447150 },
    1166 => { y: 380.3392689473816, angle: 3.12161169023200800 },
    1167 => { y: 380.4015622405495, angle: 3.09717426273453850 },
    1168 => { y: 380.4633639444982, angle: 3.07266091135163250 },
    1169 => { y: 380.5246725700746, angle: 3.04807222492457700 },
    1170 => { y: 380.5854866400065, angle: 3.0234087943914600 },
    1171 => { y: 380.6458046889385, angle: 2.99867121277529200 },
    1172 => { y: 380.705625263467, angle: 2.97386007516852350 },
    1173 => { y: 380.7649469221755, angle: 2.94897597871919200 },
    1174 => { y: 380.8237682356691, angle: 2.92401952261826900 },
    1175 => { y: 380.8820877866091, angle: 2.89899130808255150 },
    1176 => { y: 380.9399041697471, angle: 2.87389193834286150 },
    1177 => { y: 380.997215991959, angle: 2.84872201862821450 },
    1178 => { y: 381.0540218722782, angle: 2.82348215615175200 },
    1179 => { y: 381.1103204419292, angle: 2.79817296009604250 },
    1180 => { y: 381.1661103443605, angle: 2.77279504159732050 },
    1181 => { y: 381.2213902352774, angle: 2.74734901373177600 },
    1182 => { y: 381.2761587826739, angle: 2.72183549149979650 },
    1183 => { y: 381.3304146668656, angle: 2.69625509181098050 },
    1184 => { y: 381.3841565805208, angle: 2.67060843346866650 },
    1185 => { y: 381.4373832286923, angle: 2.64489613715579850 },
    1186 => { y: 381.4900933288487, angle: 2.61911882541661800 },
    1187 => { y: 381.542285610905, angle: 2.5932771226440950 },
    1188 => { y: 381.5939588172533, angle: 2.56737165506261150 },
    1189 => { y: 381.6451117027935, angle: 2.54140305071270250 },
    1190 => { y: 381.6957430349627, angle: 2.51537193943473400 },
    1191 => { y: 381.7458515937652, angle: 2.48927895285279550 },
    1192 => { y: 381.795436171802, angle: 2.46312472435980100 },
    1193 => { y: 381.8444955742996, angle: 2.43690988909939800 },
    1194 => { y: 381.8930286191392, angle: 2.41063508395078950 },
    1195 => { y: 381.9410341368848, angle: 2.38430094751291650 },
    1196 => { y: 381.9885109708113, angle: 2.35790812008559650 },
    1197 => { y: 382.0354579769329, angle: 2.33145724365598350 },
    1198 => { y: 382.0818740240302, angle: 2.30494896187914250 },
    1199 => { y: 382.1277579936778, angle: 2.27838392006267050 },
    1200 => { y: 382.1731087802709, angle: 2.25176276514898600 },
    1201 => { y: 382.2179252910519, angle: 2.22508614569981150 },
    1202 => { y: 382.2622064461374, angle: 2.19835471187662400 },
    1203 => { y: 382.3059511785433, angle: 2.1715691154250150 },
    1204 => { y: 382.3491584342112, angle: 2.14473000965783700 },
    1205 => { y: 382.3918271720337, angle: 2.11783804943588700 },
    1206 => { y: 382.433956363879, angle: 2.09089389115234400 },
    1207 => { y: 382.4755449946162, angle: 2.06389819271374700 },
    1208 => { y: 382.5165920621396, angle: 2.03685161352331100 },
    1209 => { y: 382.5570965773928, angle: 2.00975481446205850 },
    1210 => { y: 382.5970575643925, angle: 1.98260845787186750 },
    1211 => { y: 382.6364740602522, angle: 1.95541320753718900 },
    1212 => { y: 382.6753451152051, angle: 1.9281697286666900 },
    1213 => { y: 382.7136697926273, angle: 1.90087868787512750 },
    1214 => { y: 382.7514471690602, angle: 1.87354075316601050 },
    1215 => { y: 382.7886763342329, angle: 1.84615659391121750 },
    1216 => { y: 382.8253563910837, angle: 1.81872688083552700 },
    1217 => { y: 382.8614864557823, angle: 1.79125228599455200 },
    1218 => { y: 382.8970656577507, angle: 1.76373348275971950 },
    1219 => { y: 382.9320931396845, angle: 1.7361711457963750 },
    1220 => { y: 382.966568057573, angle: 1.70856595104792850 },
    1221 => { y: 383.0004895807203, angle: 1.68091857571413250 },
    1222 => { y: 383.0338568917646, angle: 1.6532296982348300 },
    1223 => { y: 383.0666691866983, angle: 1.62549999826925300 },
    1224 => { y: 383.0989256748875, angle: 1.59773015667668100 },
    1225 => { y: 383.1306255790905, angle: 1.56992085549903100 },
    1226 => { y: 383.1617681354771, angle: 1.54207277794027650 },
    1227 => { y: 383.1923525936466, angle: 1.51418660834694250 },
    1228 => { y: 383.2223782166462, angle: 1.48626303218968450 },
    1229 => { y: 383.2518442809885, angle: 1.45830273604269050 },
    1230 => { y: 383.2807500766691, angle: 1.43030640756572250 },
    1231 => { y: 383.3090949071835, angle: 1.40227473548213800 },
    1232 => { y: 383.3368780895443, angle: 1.37420840956211200 },
    1233 => { y: 383.3640989542971, angle: 1.34610812060041550 },
    1234 => { y: 383.3907568455371, angle: 1.31797456039755100 },
    1235 => { y: 383.4168511209247, angle: 1.28980842174027900 },
    1236 => { y: 383.4423811517009, angle: 1.26161039838081200 },
    1237 => { y: 383.4673463227027, angle: 1.23338118501752900 },
    1238 => { y: 383.4917460323778, angle: 1.20512147727422750 },
    1239 => { y: 383.5155796927986, angle: 1.17683197168102900 },
    1240 => { y: 383.5388467296776, angle: 1.14851336565283050 },
    1241 => { y: 383.5615465823797, angle: 1.12016635746998850 },
    1242 => { y: 383.5836787039371, angle: 1.09179164625739350 },
    1243 => { y: 383.6052425610615, angle: 1.06338993196478650 },
    1244 => { y: 383.6262376341574, angle: 1.03496191534632350 },
    1245 => { y: 383.6466634173346, angle: 1.00650829793825450 },
    1246 => { y: 383.6665194184203, angle: 0.97802978204125450 },
    1247 => { y: 383.6858051589707, angle: 0.94952707069830900 },
    1248 => { y: 383.7045201742833, angle: 0.92100086767313700 },
    1249 => { y: 383.7226640134073, angle: 0.89245187743169950 },
    1250 => { y: 383.7402362391547, angle: 0.863880805119700 },
    1251 => { y: 383.7572364281112, angle: 0.83528835654288900 },
    1252 => { y: 383.7736641706459, angle: 0.80667523814449700 },
    1253 => { y: 383.7895190709212, angle: 0.7780421569876100 },
    1254 => { y: 383.8048007469031, angle: 0.74938982073054950 },
    1255 => { y: 383.819508830369, angle: 0.72071893760833400 },
    1256 => { y: 383.8336429669182, angle: 0.6920302164108450 },
    1257 => { y: 383.8472028159792, angle: 0.66332436646266950 },
    1258 => { y: 383.8601880508183, angle: 0.63460209759964800 },
    1259 => { y: 383.8725983585476, angle: 0.60586412015093900 },
    1260 => { y: 383.8844334401327, angle: 0.57711114491580100 },
    1261 => { y: 383.8956930103993, angle: 0.54834388314276800 },
    1262 => { y: 383.9063767980405, angle: 0.51956304650880050 },
    1263 => { y: 383.9164845456234, angle: 0.490769347098275150 },
    1264 => { y: 383.9260160095951, angle: 0.461963497380673750 },
    1265 => { y: 383.9349709602886, angle: 0.433146210190669250 },
    1266 => { y: 383.9433491819283, angle: 0.404318198705635400 },
    1267 => { y: 383.9511504726357, angle: 0.375480176424844600 },
    1268 => { y: 383.9583746444331, angle: 0.346632857148223400 },
    1269 => { y: 383.9650215232496, angle: 0.31777695495523450 },
    1270 => { y: 383.9710909489241, angle: 0.288913184182182350 },
    1271 => { y: 383.9765827752098, angle: 0.26004225940206300 },
    1272 => { y: 383.9814968697773, angle: 0.231164895403407700 },
    1273 => { y: 383.9858331142185, angle: 0.202281807167125900 },
    1274 => { y: 383.9895914040486, angle: 0.173393709846465050 },
    1275 => { y: 383.9927716487089, angle: 0.14450131874568300 },
    1276 => { y: 383.9953737715696, angle: 0.115605349297575300 },
    1277 => { y: 383.9973977099306, angle: 0.086706517041991300 },
    1278 => { y: 383.9988434150238, angle: 0.057805537606334200 },
    1279 => { y: 383.9997108520141, angle: 0.028903126681082850 },
    1280 => { y: 384.0, angle: 0.0 }
  }
end