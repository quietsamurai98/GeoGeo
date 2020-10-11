require 'lib/geo_geo.rb'

# @param [GTK::Args] args
def tick(args)
  trace!(GeoGeo::MagicHelper)
  GTK::Trace.flush_trace true
  stress = 0 # Crank this up if you want to do stress testing. Polygons are currently *very* slow, so don't go too crazy.

  args.state.type ||= 7
  args.outputs.labels << {x: 10, y: 30, text: "FPS : #{$gtk.current_framerate.to_s.to_i}", r: 255, g: 0, b: 0}

  box(args, stress) if args.state.type == 0
  box_circ(args, stress) if args.state.type == 1
  circ(args, stress) if args.state.type == 2
  point_poly(args, stress) if args.state.type == 3
  circ_poly(args, stress) if args.state.type == 4
  box_poly(args, stress) if args.state.type == 5
  poly(args, stress) if args.state.type == 6
  conv_poly(args, stress) if args.state.type == 7

  args.state.type == 3 ? $gtk.show_cursor : $gtk.hide_cursor
  args.state.type = (args.state.type + 1) % 8 if args.inputs.keyboard.key_down.space
end

def box(args, iters)
  a = GeoGeo::Box.new_drgtk(640 - 100, 360 - 100, 200, 200)
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b = GeoGeo::Box.new_drgtk(mx - 50, my - 50, 100, 100)
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = GeoGeo.intersect?(a, b)

  args.outputs.primitives << [
      {
          x: a.left,
          y: a.bottom,
          w: a.width,
          h: a.height,
          r: coll ? 255 : 0,
          g: 0,
          b: 0
      }.solid,
      {
          x: b.left,
          y: b.bottom,
          w: b.width,
          h: b.height,
          r: coll ? 255 : 0,
          g: 0,
          b: 0
      }.solid
  ]
end

def box_circ(args, iters)
  a = GeoGeo::Circle.new(640.0, 360.0, 100.0)
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b = GeoGeo::Box.new_drgtk(mx - 50, my - 50, 100, 100)
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = GeoGeo.intersect?(a, b)

  args.outputs.primitives << [
      {
          x: a.left,
          y: a.bottom,
          w: a.width,
          h: a.height,
          path: 'sprites/circle.png',
          r: coll ? 255 : 0,
          g: 0,
          b: 0
      }.sprite,
      {
          x: b.left,
          y: b.bottom,
          w: b.width,
          h: b.height,
          r: coll ? 255 : 0,
          g: 0,
          b: 0
      }.solid
  ]
end

def circ(args, iters)
  a = GeoGeo::Circle.new(640.0, 360.0, 100.0)
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b = GeoGeo::Circle.new(mx, my, 50.0)
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = GeoGeo.intersect?(a, b)

  args.outputs.primitives << [
      {
          x: a.left,
          y: a.bottom,
          w: a.width,
          h: a.height,
          path: 'sprites/circle.png',
          r: coll ? 255 : 0,
          g: 0,
          b: 0
      }.sprite,
      {
          x: b.left,
          y: b.bottom,
          w: b.width,
          h: b.height,
          path: 'sprites/circle.png',
          r: coll ? 255 : 0,
          g: 0,
          b: 0
      }.sprite
  ]
end


# @param [GTK::Args] args
# @param [Object] iters
def point_poly(args, iters)
  verts = [[0, 0], [110, 40], [220, 20], [180, 90], [200, 160], [60, 180], [40, 120], [180, 140], [160, 40], [120, 60], [100, 200], [60, 190], [20, 220], [30, 110], [0, 0]]
  $self_intersecting_a ||= GeoGeo::Polygon.new(verts)
  a = $self_intersecting_a
  a.set_center([640.0, 360.0])
  b = args.inputs.mouse
  iters.times do |_|
    a.point_inside?(b.x, b.y)
  end
  coll = a.point_inside?(b.x, b.y)
  lines = a.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }
  end
  args.outputs.lines << lines
  args.outputs.lines << a.hull_verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: 0,
        g: 0,
        b: 255,
        a: 128
    }
  end
  #puts a.hull_verts
end

# @param [GTK::Args] args
# @param [Object] iters
def circ_poly(args, iters)
  verts = [[0, 0], [110, 40], [220, 20], [180, 90], [200, 160], [60, 180], [40, 120], [180, 140], [160, 40], [120, 60], [100, 200], [60, 190], [20, 220], [30, 110], [0, 0]]
  $self_intersecting_a ||= GeoGeo::Polygon.new(verts)
  a = $self_intersecting_a
  a.set_center([640.0, 360.0])
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b = GeoGeo::Circle.new(mx, my, 8.0)
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = GeoGeo.intersect?(a, b)
  prims = a.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }.line
  end
  prims << {
      x: b.left,
      y: b.bottom,
      w: b.width,
      h: b.height,
      path: 'sprites/circle.png',
      r: coll ? 255 : 0,
      g: 0,
      b: 0
  }.sprite
  args.outputs.primitives << prims
end

# @param [GTK::Args] args
# @param [Object] iters
def box_poly(args, iters)
  verts = [[0, 0], [110, 40], [220, 20], [180, 90], [200, 160], [60, 180], [40, 120], [180, 140], [160, 40], [120, 60], [100, 200], [60, 190], [20, 220], [30, 110], [0, 0]]
  $self_intersecting_a ||= GeoGeo::Polygon.new(verts)
  a = $self_intersecting_a
  a.set_center([640.0, 360.0])
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b = GeoGeo::Box.new_drgtk(mx - 12, my - 12, 24, 24)
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = GeoGeo.intersect?(a, b)
  prims = a.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }.line
  end
  prims << {
      x: b.left,
      y: b.bottom,
      w: b.width,
      h: b.height,
      r: coll ? 255 : 0,
      g: 0,
      b: 0
  }.solid
  args.outputs.primitives << prims
end

# @param [GTK::Args] args
# @param [Object] iters
def poly(args, iters)
  star_verts = [
      [0, 30],
      [-10, 11],
      [-30, 7],
      [-16, -9],
      [-19, -30],
      [0, -21],
      [19, -30],
      [16, -9],
      [30, 7],
      [10, 11],
      [0, 30]
  ]
  verts = [
      [-20.0, 20.0],
      [0.0, 0.0],
      [20.0, 20.0],
      [0.0, -20.0]
  ]
  a = GeoGeo::Polygon.new(verts.map { |v| v.map { |w| w * 5.0 } })
  b = GeoGeo::Polygon.new(verts.map { |v| v.map { |w| w * 5.0 } })
  a.set_center([640.0, 360.0])
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b.set_center([mx, my])
  a.theta = Kernel.tick_count / 360
  b.theta = -Kernel.tick_count / 360
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = GeoGeo.intersect?(a, b)
  prims = a.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }.line
  end + b.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }.line
  end
  args.outputs.primitives << prims
end

# @param [GTK::Args] args
# @param [Object] iters
def conv_poly(args, iters)
  verts = [
      [0, 30],
      [-10, 11],
      [-30, 7],
      [-16, -9],
      [-19, -30],
      [0, -21],
      [19, -30],
      [16, -9],
      [30, 7],
      [10, 11],
      [0, 30]
  ]
  verts = [
      [-20, 20],
      [0, 0],
      [20, 20],
      [0, -20]
  ]
  a = GeoGeo::Polygon.new(GeoGeo::Polygon.new(verts.map { |v| v.map { |w| w * 5 } }).hull_verts)
  b = GeoGeo::Polygon.new(GeoGeo::Polygon.new(verts.map { |v| v.map { |w| w * 5 } }).hull_verts)
  a.set_center([640.0, 360.0])
  mx = args.inputs.mouse.x
  my = args.inputs.mouse.y
  b.set_center([mx, my])
  a.theta = Kernel.tick_count / 360
  b.theta = -Kernel.tick_count / 360
  iters.times do |_|
    GeoGeo.intersect?(a, b)
  end
  coll = true && GeoGeo.intersect?(a, b)
  prims = a.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }.line
  end + b.verts.each_cons(2).map do |p|
    {
        x: p[0].x,
        y: p[0].y,
        x2: p[1].x,
        y2: p[1].y,
        r: coll ? 255 : 0,
        g: 0,
        b: 0
    }.line
  end
  args.outputs.primitives << prims
end