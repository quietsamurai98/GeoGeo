module GeoGeo
  class Shape2D
    # @return [Float]
    attr_reader :left, :right, :bottom, :top, :width, :height

    # @param [Float, Integer] left
    # @param [Float, Integer] right
    # @param [Float, Integer] bottom
    # @param [Float, Integer] top
    # @return [GeoGeo::Shape2D]
    def initialize(left, right, bottom, top)
      @left = left
      @right = right
      @bottom = bottom
      @top = top
      @width = top - bottom
      @height = right - left
    end

    # @return [Array<Float>]
    def aabb_center
      [(@left + @right) / 2.0, (@top + @bottom) / 2.0]
    end

    # @param [Float] dx
    # @param [Float] dy
    # @return [nil]
    def shift(dx, dy)
      @left += dx
      @right += dx
      @bottom += dy
      @top += dy
    end

    # @param [Float] x
    # @param [Float] y
    # @return [Boolean] Whether or not the point is contained within the shape.
    def point_inside?(x, y)
      raise "The method point_inside?(x,y) must be defined by the class that inherits Shape2D."
    end
  end

  class Box < Shape2D

    # @param [Float, Integer] left
    # @param [Float, Integer] right
    # @param [Float, Integer] bottom
    # @param [Float, Integer] top
    # @return [Box]
    def initialize(left, right, bottom, top)
      super(left, right, bottom, top)
    end

    # @param [Integer] x
    # @param [Integer] y
    # @param [Integer] w
    # @param [Integer] h
    # @return [GeoGeo::Box]
    def Box.new_drgtk(x, y, w, h)
      Box.new(x, x + w, y, y + h)
    end

    # @param [Float] x
    # @param [Float] y
    # @return [Boolean] Whether or not the point is contained within the shape.
    def point_inside?(x, y)
      (@left..@right).cover?(x) && (@bottom..@top).cover?(y)
    end

    protected

    # @return [Integer]
    def __internal_test_mtx_idx
      0
    end
  end

  class Circle < Shape2D
    # @return [Float]
    attr_reader :x, :y, :r, :r2

    # @param [Float] x
    # @param [Float] y
    # @param [Float] r
    # @return [GeoGeo::Circle]
    def initialize(x, y, r)
      @x = x
      @y = y
      @r = r
      @r2 = r * r
      super(x - r, x + r, y - r, y + r)
    end

    # @param [Float] x
    # @param [Float] y
    # @return [nil]
    def set_center(x, y)
      shift(x - @x, y - @y)
    end

    # @return [Array<Float>]
    def get_center
      [@x, @y]
    end

    # @param [Float] dx
    # @param [Float] dy
    # @return [nil]
    def shift(dx, dy)
      super(dx, dy)
      @x += dx
      @y += dy
    end

    # @param [Float] x
    # @param [Float] y
    # @return [Boolean] Whether or not the point is contained within the shape.
    def point_inside?(x, y)
      (@x - x) * (@x - x) + (@y - y) * (@y - y) <= @r2
    end

    protected

    # @return [Integer]
    def __internal_test_mtx_idx
      1
    end
  end


  class Polygon < Shape2D
    # @return [Array<Array<Float>>]
    attr_reader :verts, :hull_verts, :hull_norms
    # @return [Boolean]
    attr_reader :convex
    # @return [Float]
    attr_reader :theta

    # @param [Array<Array<Float, Integer>>] verts List of vertices in clockwise order. If verts[0]!=verts[-1], a copy of the first vert will be appended.
    # @param [Array<Float>] center The center point of the polygon. Defaults to the center of the AABB
    # @param [Float] theta The initial angle of the polygon, in radians
    # @return [GeoGeo::Polygon]
    def initialize(verts, center = nil, theta = 0.0)
      # trace!
      @verts = verts.map(&:clone)
      @verts << [*@verts[0]] if @verts[0] != @verts[-1]
      __calc_hull
      @convex = @verts == @hull_verts
      @theta = theta
      super(*@verts.map(&:x).minmax, *@verts.map(&:y).minmax)
      # @type [Array<Float>]
      @center = (center || aabb_center).clone
    end

    # @param [Float] theta
    # @return [Float]
    def theta=(theta)
      d_theta = theta - @theta
      c, s = Math.cos(d_theta), Math.sin(d_theta)
      t, b, l, r = @center.y, @center.y, @center.x, @center.x
      @verts.each do |v|
        v.x, v.y = @center.x + (v.x - @center.x) * c - (v.y - @center.y) * s, @center.y + (v.x - @center.x) * s + (v.y - @center.y) * c
        l = v.x if v.x < l
        r = v.x if v.x > r
        b = v.y if v.y < b
        t = v.y if v.y > t
      end
      @hull_norms.each do |v|
        v.x, v.y = v.x * c - v.y * s, v.x * s + v.y * c
      end
      @left, @right, @bottom, @top, @width, @height = l, r, b, t, r - l, t - b
      @theta = theta
    end

    # @param [Array<Float>] point
    # @return [nil]
    def set_center(point)
      shift(point.x - @center.x, point.y - @center.y)
    end

    # @param [Float] dx
    # @param [Float] dy
    # @return [nil]
    def shift(dx, dy)
      super(dx, dy)
      @center.x += dx
      @center.y += dy
      @verts.each do |v|
        v.x += dx
        v.y += dy
      end
    end

    # @param [Float] x
    # @param [Float] y
    # @return [Boolean] Whether or not the point is contained within the shape.
    def point_inside?(x, y)
      return false unless (@left..@right).cover?(x) && (@bottom..@top).cover?(y)

      winding_number = 0
      @verts.each_cons(2) do
        # @type [Array<Array<Float>>] seg
      |seg|
        if seg[0].y <= y
          winding_number += 1 if seg[1].y > y && __left?(seg[0], seg[1], [x, y]) > 0
        else
          winding_number -= 1 if seg[1].y <= y && __left?(seg[0], seg[1], [x, y]) < 0
        end
      end

      winding_number != 0
    end

    private

    # @param [Array<Float>] a
    # @param [Array<Float>] b
    # @param [Array<Float>] c
    # @return [Float]
    def __left?(a, b, c)
      (b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)
    end

    # @return [nil]
    def __calc_hull
      if @verts.length > 4
        pivot = @verts[0]
        @verts.each do |v|
          pivot = v if v.y < pivot.y || (v.y == pivot.y && v.x < pivot.x)
        end
        points = @verts.map do |v|
          {x: v, y: [Math.atan2(v.y - pivot.y, v.x - pivot.x), (v.x - pivot.x) * (v.x - pivot.x) + (v.y - pivot.y) * (v.y - pivot.y)]}
        end.sort_by(&:y)
        # @type [Array] points
        points = points.map.with_index do |v, i|
          if i != points.length - 1 && v.y[0] == points[i + 1].y[0]
            v.x #nil
          else
            v.x
          end
        end
        points.compact!
        @hull_verts = []
        points.each do |v|
          if @hull_verts.length < 3
            @hull_verts.push(v) if @hull_verts[-1] != v
          else
            while __left?(@hull_verts[-2], @hull_verts[-1], v) < 0
              @hull_verts.pop
            end
            @hull_verts.push(v) if @hull_verts[-1] != v
          end
        end
        if @hull_verts.length + 1 == @verts.length
          @hull_verts.rotate!(@hull_verts.index(@verts[0]))
        end
        @hull_verts.push(@hull_verts[0])
      else
        @hull_verts = @verts
      end

      @hull_norms = @hull_verts.each_cons(2).map do
        # @type [Array<Float>] v1
        # @type [Array<Float>] v2
      |v1, v2|
        # @type [Array<Float>] norm
        norm = [v2.y - v1.y, v1.x - v2.x]
        # @type [Array<Float>] norm
        norm = [-norm.x, -norm.y] if norm.x < 0
        nx = norm.x
        ny = norm.y
        mag = Math.sqrt((nx * nx) + (ny * ny))
        norm.x /= mag
        norm.y /= mag
        norm
      end.uniq
    end

    protected

    # @return [Integer]
    def __internal_test_mtx_idx
      2
    end
  end


  # @param [GeoGeo::Box, GeoGeo::Circle, GeoGeo::Polygon] a
  # @param [GeoGeo::Box, GeoGeo::Circle, GeoGeo::Polygon] b
  # @return [Boolean]
  def GeoGeo::intersect?(a, b)
    #noinspection RubyResolve
    GeoGeo::MagicHelper.intersect?(a, b)
  end
end

# Hide away all the internal logic
class GeoGeoHelper
  TestMtx = [
      [:box_intersect?, :box_circ_intersect?, :box_poly_intersect?],
      [:circ_box_intersect?, :circ_intersect?, :circ_poly_intersect?],
      [:poly_box_intersect?, :poly_circ_intersect?, :poly_intersect?],
  ]

  # @param [GeoGeo::Box, GeoGeo::Circle, GeoGeo::Polygon] a
  # @param [GeoGeo::Box, GeoGeo::Circle, GeoGeo::Polygon] b
  # @return [Boolean]
  def intersect?(a, b)
    self.send(GeoGeoHelper::TestMtx[a.__internal_test_mtx_idx][b.__internal_test_mtx_idx], a, b)
  end

  # @param [GeoGeo::Shape2D] a
  # @param [GeoGeo::Shape2D] b
  # @return [Boolean]
  def aabb_intersect?(a, b)
    (a.left <= b.right) && (b.left <= a.right) && (a.bottom <= b.top) && (b.bottom <= a.top)
  end

  # @param [GeoGeo::Box] a
  # @param [GeoGeo::Box] b
  # @return [Boolean]
  def box_intersect?(a, b)
    aabb_intersect?(a, b)
  end

  # @param [GeoGeo::Box] a
  # @param [GeoGeo::Circle] b
  # @return [Boolean]
  def box_circ_intersect?(a, b)
    # AABBxAABB test to trivially reject.
    return false unless aabb_intersect?(a, b)
    dx = b.x - (b.x < a.left ? a.left : b.x > a.right ? a.right : b.x)
    dy = b.y - (b.y < a.bottom ? a.bottom : b.y > a.top ? a.top : b.y)
    return dx * dx + dy * dy <= b.r2
  end

  # WARNING: This is *slow*
  # @param [GeoGeo::Box] a
  # @param [GeoGeo::Polygon] b
  # @return [Boolean]
  def box_poly_intersect?(a, b)
    return false unless aabb_intersect?(a, b)
    # Test if the box is inside the polygon
    return true if b.point_inside?(a.left, a.top)
    #return true if b.point_inside?(a.right, a.top)
    #return true if b.point_inside?(a.left, a.bottom)
    #return true if b.point_inside?(a.right, a.bottom)

    # TODO: This feels like it is hilariously over engineered.

    cs_verts = b.verts.map do |v|
      code = 0b0000
      if v.x < a.left
        code |= 0b0001
      elsif v.x > a.right
        code |= 0b0010
      end
      if v.y < a.bottom
        code |= 0b0100
      elsif v.y > a.top
        code |= 0b1000
      end
      return true if code == 0b0000 # Vertex within box indicates collision. Return early
      [v.x, v.y, code]
    end
    # @type [Array] cs_edges
    cs_edges = cs_verts.each_cons(2).find_all do |v1, v2|
      0b0000 == v1[2] & v2[2]
    end
    # Test if any lines trivially cross opposite bounds, return early if so
    cs_edges.each do |v1, v2|
      return true if v1[2] | v2[2] == 0b0011 || v1[2] | v2[2] == 0b1100
    end
    # Test if any lines non-trivially cross a relevant boundary
    cs_edges.each do
      # @type [Array<Float>] p1
      # @type [Array<Float>] p2
    |p1, p2|
      x_min, x_max = p1.x, p2.x
      x_min, x_max = x_max, x_min if (x_min > x_max)
      x_min, x_max = x_min.greater(a.left), x_max.lesser(a.right)
      return false if x_min > x_max
      y_min, y_max = p1.y, p2.y
      dx = p2.x - p1.x
      if dx.abs > 0.0000001
        ma = (p2.y - p1.y) / dx
        mb = p1.y - ma * p1.x
        y_min = ma * x_min + mb
        y_max = ma * x_max + mb
      end
      y_min, y_max = y_max, y_min if (y_min > y_max)
      y_max = y_max.lesser(a.top)
      y_min = y_min.greater(a.bottom)
      return true if y_min <= y_max
    end
    false
  end

  # @param [GeoGeo::Circle] a
  # @param [GeoGeo::Box] b
  # @return [Boolean]
  def circ_box_intersect?(a, b)
    box_circ_intersect?(b, a)
  end

  # @param [GeoGeo::Circle] a
  # @param [GeoGeo::Circle] b
  # @return [Boolean]
  def circ_intersect?(a, b)
    # Don't do a preliminary AABB test here. It makes things slower.
    dx = a.x - b.x
    dy = a.y - b.y
    dx * dx + dy * dy <= (a.r + b.r) * (a.r + b.r)
  end

  # WARNING: This is *slow*
  # @param [GeoGeo::Circle] a
  # @param [GeoGeo::Polygon] b
  # @return [Boolean]
  def circ_poly_intersect?(a, b)
    return false unless aabb_intersect?(a, b)

    return true if b.point_inside?(a.x, a.y)

    b.verts.each_cons(2).any? do
      # @type p1 [Array<Float>]
      # @type p2 [Array<Float>]
    |p1, p2|
      ac = [a.x - p1.x, a.y - p1.y]
      return true if dot(ac, ac) <= a.r2 # Vert in circle. Early return
      ab = [p2.x - p1.x, p2.y - p1.y]
      t = (dot(ac, ab) / dot(ab, ab)).clamp(0, 1)
      h = [(ab.x * t + p1.x) - a.x, (ab.y * t + p1.y) - a.y]
      dot(h, h) <= a.r2
    end
  end

  # WARNING: This is *slow*
  # @param [GeoGeo::Polygon] a
  # @param [GeoGeo::Box] b
  # @return [Boolean]
  def poly_box_intersect?(a, b)
    box_poly_intersect?(b, a)
  end

  # WARNING: This is *slow*
  # @param [GeoGeo::Polygon] a
  # @param [GeoGeo::Circle] b
  # @return [Boolean]
  def poly_circ_intersect?(a, b)
    circ_poly_intersect?(b, a)
  end

  # WARNING: This is *very* *slow*
  # @param [GeoGeo::Polygon] a
  # @param [GeoGeo::Polygon] b
  # @return [Boolean]
  def poly_intersect?(a, b)
    return false unless aabb_intersect?(a, b)
    # TODO: Polygons
    # Phase 1: SAT test with the convex hulls. If the convex hulls don't collide, the polygons don't collide.
    return false unless sat_intersect?(a.hull_norms, a.hull_verts, b.hull_verts)
    return false unless sat_intersect?(b.hull_norms, a.hull_verts, b.hull_verts)
    return true if a.convex && b.convex # If both are convex, SAT is all you need to see if they are colliding.
    # Phase 2: Check if one covers the other, using the first vert as a proxy.
    return true if a.point_inside?(*b.verts[0]) || b.point_inside?(*a.verts[0])
    # Phase 3: Check if the two perimeters overlap.
    a.verts.each_cons(2).any? do |e1|
      b.verts.each_cons(2).any? do |e2|
        line_line_intersect?(e1, e2)
      end
    end
  end

  private

  # @param [Array<Float>] v1
  # @param [Array<Float>] v2
  # @return [Float]
  def dot(v1, v2)
    (v1.x * v2.x) + (v1.y * v2.y)
  end

  # @param [Array<Float>] a
  # @param [Array<Float>] b
  # @param [Array<Float>] c
  # @return [Boolean]
  def ccw(a, b, c)
    (c.y - a.y) * (b.x - a.x) > (b.y - a.y) * (c.x - a.x)
  end

  # @param [Array<Array<Float>>, Enumerable<Array<Float>>] a
  # @param [Array<Array<Float>>, Enumerable<Array<Float>>] b
  # @return [Boolean]
  def line_line_intersect?(a, b)
    ccw(a[0], b[0], b[1]) != ccw(a[1], b[0], b[1]) && ccw(a[0], a[1], b[0]) != ccw(a[0], a[1], b[1])
  end

  # WARNING: This is *slow*. Why?
  # @param [Array<Array<Float>>] axes
  # @param [Array<Array<Float>>] vert_a
  # @param [Array<Array<Float>>] vert_b
  # @return [Boolean]
  def sat_intersect?(axes, vert_a, vert_b)
    axes.none? do
      # @type [Array<Float>] axis
    |axis|
      # Test to see if the polygons do *not* overlap on this axis.

      a_min, a_max = vert_a.minmax_by do
        # @type [Array<Float>] v
      |v|
        axis.x * v.x + axis.y * v.y
      end.map do
        # @type [Array<Float>] v
      |v|
        axis.x * v.x + axis.y * v.y
      end # minmax_by.map is *way* faster than map.minmax

      b_min, b_max = vert_b.minmax_by do
        # @type [Array<Float>] v
      |v|
        axis.x * v.x + axis.y * v.y
      end.map do
        # @type [Array<Float>] v
      |v|
        axis.x * v.x + axis.y * v.y
      end # minmax_by.map is *way* faster than map.minmax

      (a_min > b_max) || (b_min > a_max) # A separating axis exists. Thus, they cannot be intersecting.
    end
  end

end

# Adds the MagicHelper sneakily, so it isn't listed in code completion.
# todo this is dumb
GeoGeo.const_set("MagicHelper", GeoGeoHelper.new) unless GeoGeo.const_defined?(:MagicHelper)