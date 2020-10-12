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
    # @return [Array<Float>]
    attr_reader :verts_x, :hull_verts_x, :hull_norms_x, :verts_y, :hull_verts_y, :hull_norms_y
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
      @verts_x = @verts.map(&:first)
      @verts_y = @verts.map(&:last)
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
      return theta if d_theta == 0
      c, s = Math.cos(d_theta), Math.sin(d_theta)
      t, b, l, r = @center.y, @center.y, @center.x, @center.x
      index = 0
      limit = @verts.length
      while index < limit
        vx = @verts_x[index]
        vy = @verts_y[index]
        vx, vy = @center.x + (vx - @center.x) * c - (vy - @center.y) * s, @center.y + (vx - @center.x) * s + (vy - @center.y) * c
        @verts_x[index] = vx
        @verts_y[index] = vy
        @verts[index] = [vx, vy]
        l = vx if vx < l
        r = vx if vx > r
        b = vy if vy < b
        t = vy if vy > t
        index+=1
      end
      index = 0
      limit = @hull_verts.length
      while index < limit
        vx = @hull_verts_x[index]
        vy = @hull_verts_y[index]
        vx, vy = @center.x + (vx - @center.x) * c - (vy - @center.y) * s, @center.y + (vx - @center.x) * s + (vy - @center.y) * c
        @hull_verts_x[index] = vx
        @hull_verts_y[index] = vy
        @hull_verts[index] = [vx, vy]
        index+=1
      end
      index = 0
      limit = @hull_norms.length
      while index < limit
        vx = @hull_norms_x[index]
        vy = @hull_norms_y[index]
        vx, vy = @center.x + (vx - @center.x) * c - (vy - @center.y) * s, @center.y + (vx - @center.x) * s + (vy - @center.y) * c
        @hull_norms_x[index] = vx
        @hull_norms_y[index] = vy
        @hull_norms[index] = [vx, vy]
        index+=1
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
      @hull_verts.each do |v|
        v.x += dx
        v.y += dy
      end
      @hull_norms.each do |v|
        v.x += dx
        v.y += dy
      end
      @verts_x = @verts.map(&:x)
      @verts_y = @verts.map(&:y)
      @hull_verts_x = @hull_verts.map(&:x)
      @hull_verts_y = @hull_verts.map(&:y)
      @hull_norms_x = @hull_norms.map(&:x)
      @hull_norms_y = @hull_norms.map(&:y)
    end

    # @param [Float] x
    # @param [Float] y
    # @return [Boolean] Whether or not the point is contained within the shape.
    def point_inside?(x, y)
      return false unless @left < x && x < @right && @bottom < y && y < @top

      winding_number = 0
      # This isn't very idiomatic ruby, but it is faster this way
      index = 0
      limit = @verts.length - 1
      while index < limit
        if @verts_y[index] <= y
          winding_number += 1 if @verts_y[index + 1] > y && __left(@verts_x[index], @verts_y[index], @verts_x[index + 1], @verts_y[index + 1], x, y) > 0
        else
          winding_number -= 1 if @verts_y[index + 1] <= y && __left(@verts_x[index], @verts_y[index], @verts_x[index + 1], @verts_y[index + 1], x, y) < 0
        end
        index += 1
      end

      winding_number != 0
    end

    private

    # @param [Float] ax
    # @param [Float] ay
    # @param [Float] bx
    # @param [Float] by
    # @param [Float] cx
    # @param [Float] cy
    # @return [Float]
    def __left(ax, ay, bx, by, cx, cy)
      (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    end

    # @return [nil]
    def __calc_hull
      if @verts.length > 4
        pivot = @verts[0]
        @verts.each do |v|
          pivot = [*v] if v.y < pivot.y || (v.y == pivot.y && v.x < pivot.x)
        end
        points = @verts.map do |v|
          {x: [*v], y: [Math.atan2(v.y - pivot.y, v.x - pivot.x), (v.x - pivot.x) * (v.x - pivot.x) + (v.y - pivot.y) * (v.y - pivot.y)]}
        end.sort_by(&:y)
        # @type [Array] points
        points = points.map(&:x)
        hull_verts = []
        hull_verts_x = []
        hull_verts_y = []
        points.each do |v|
          vx = v.x
          vy = v.y
          if hull_verts.length < 3
            if hull_verts[-1] != v
              hull_verts.push([*v])
              hull_verts_x.push(vx)
              hull_verts_y.push(vy)
            end
          else
            while __left(hull_verts_x[-2], hull_verts_y[-2], hull_verts_x[-1], hull_verts_y[-1], vx, vy) < 0
              hull_verts.pop
              hull_verts_x.pop
              hull_verts_y.pop
            end
            if hull_verts[-1] != v
              hull_verts.push([*v])
              hull_verts_x.push(vx)
              hull_verts_y.push(vy)
            end
          end
        end
        @hull_verts = hull_verts
        @hull_verts_x = hull_verts_x
        @hull_verts_y = hull_verts_y
        if @hull_verts.length + 1 == @verts.length
          tmp = @hull_verts.index(@verts[0])
          @hull_verts.rotate!(tmp)
          @hull_verts_x.rotate!(tmp)
          @hull_verts_y.rotate!(tmp)
        end
        @hull_verts.push([*@hull_verts[0]])
        @hull_verts_x.push(@hull_verts_x[0])
        @hull_verts_y.push(@hull_verts_y[0])
      else
        @hull_verts = @verts.map(&:clone)
        @hull_verts_x = @verts_x.clone
        @hull_verts_y = @verts_y.clone
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
      @hull_norms_x = @hull_norms.map(&:x)
      @hull_norms_y = @hull_norms.map(&:y)
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

    index = 0
    limit = b.verts.length
    cs_verts = Array.new(b.verts.length)
    while index < limit
      vx = b.verts_x[index]
      vy = b.verts_y[index]
      code = 0b0000
      if vx < a.left
        code |= 0b0001
      elsif vx > a.right
        code |= 0b0010
      end
      if vy < a.bottom
        code |= 0b0100
      elsif vy > a.top
        code |= 0b1000
      end
      return true if code == 0b0000 # Vertex within box indicates collision. Return early
      cs_verts[index] = [vx, vy, code]
      index += 1
    end
    index = 0
    limit = cs_verts.length - 1
    cs_edges = []
    while index < limit
      cs_edges << [cs_verts[index], cs_verts[index + 1]] if 0b0000 == cs_verts[index][2] & cs_verts[index + 1][2]
      index += 1
    end
    # Test if any lines trivially cross opposite bounds, return early if so
    index = 0
    limit = cs_edges.length
    while index < limit
      return true if cs_edges[index][0][2] | cs_edges[index][1][2] == 0b0011 || cs_edges[index][0][2] | cs_edges[index][1][2] == 0b1100
      index += 1
    end

    # Test if any lines non-trivially cross a relevant boundary
    index = 0
    limit = cs_edges.length
    while index < limit
      # @type [Array<Float>] p1
      # @type [Array<Float>] p2
      p1, p2 = cs_edges[index]
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
      index += 1
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

  # @param [GeoGeo::Circle] a
  # @param [GeoGeo::Polygon] b
  # @return [Boolean]
  def circ_poly_intersect?(a, b)
    return false unless aabb_intersect?(a, b)
    return true if b.point_inside?(a.x, a.y)
    index = 0
    limit = b.verts.length - 1
    while index < limit
      # @type p1 [Array<Float>]
      # @type p2 [Array<Float>]
      # p1, p2 = b.verts.values_at(index, index+1)
      p1x = b.verts_x[index]
      p1y = b.verts_y[index]
      p2x = b.verts_x[index + 1]
      p2y = b.verts_y[index + 1]

      acx = a.x - p1x
      acy = a.y - p1y
      return true if acx * acx + acy * acy <= a.r2 # Vert in circle. Early return
      abx = p2x - p1x
      aby = p2y - p1y
      t = ((acx * abx + acy * aby) / (abx * abx + aby * aby)).clamp(0, 1)
      tmp1 = (abx * t + p1x) - a.x
      tmp2 = (aby * t + p1y) - a.y
      return true if (tmp1 * tmp1 + tmp2 * tmp2) <= a.r2
      index += 1
    end
    false
  end

  # @param [GeoGeo::Polygon] a
  # @param [GeoGeo::Box] b
  # @return [Boolean]
  def poly_box_intersect?(a, b)
    box_poly_intersect?(b, a)
  end

  # @param [GeoGeo::Polygon] a
  # @param [GeoGeo::Circle] b
  # @return [Boolean]
  def poly_circ_intersect?(a, b)
    circ_poly_intersect?(b, a)
  end

  # @param [GeoGeo::Polygon] a
  # @param [GeoGeo::Polygon] b
  # @return [Boolean]
  def poly_intersect?(a, b)
    return false unless aabb_intersect?(a, b)
    # TODO: Polygons
    # Phase 1: SAT test with the convex hulls. If the convex hulls don't collide, the polygons don't collide.
    return false unless sat_intersect?(a.hull_norms_x,a.hull_norms_y, a.hull_verts_x,a.hull_verts_y, b.hull_verts_x,b.hull_verts_y)
    return false unless sat_intersect?(b.hull_norms_x,b.hull_norms_y, a.hull_verts_x,a.hull_verts_y, b.hull_verts_x,b.hull_verts_y)
    return true if a.convex && b.convex # If both are convex, SAT is all you need to see if they are colliding.
    # Phase 2: Check if one covers the other, using the first vert as a proxy.
    return true if a.point_inside?(b.verts_x[0], b.verts_y[0]) || b.point_inside?(a.verts_x[0], a.verts_y[0])
    # Phase 3: Check if the two perimeters overlap.
    index = 0
    limit = a.verts.length - 1
    jimit = b.verts.length - 1
    while index < limit
      jndex = 0
      e1x1 = a.verts_x[index]
      e1x2 = a.verts_x[index+1]
      e1y1 = a.verts_y[index]
      e1y2 = a.verts_y[index+1]
      while jndex < jimit
        return true if line_line_intersect?(e1x1,e1y1,e1x2,e1y2,b.verts_x[jndex],b.verts_y[jndex],b.verts_x[jndex+1],b.verts_y[jndex+1])
        jndex += 1
      end
      index += 1
    end
    false
  end

  private

  # @param [Array<Float>] v1
  # @param [Array<Float>] v2
  # @return [Float]
  def dot(v1, v2)
    (v1.x * v2.x) + (v1.y * v2.y)
  end


  # @param [Float] ax
  # @param [Float] ay
  # @param [Float] bx
  # @param [Float] by
  # @param [Float] cx
  # @param [Float] cy
  # @return [Boolean]
  def ccw?(ax, ay, bx, by, cx, cy)
    (cy - ay) * (bx - ax) > (by - ay) * (cx - ax)
  end


  # @param [Float] ax1
  # @param [Float] ay1
  # @param [Float] ax2
  # @param [Float] ay2
  # @param [Float] bx1
  # @param [Float] by1
  # @param [Float] bx2
  # @param [Float] by2
  # @return [Boolean]
  def line_line_intersect?(ax1,ay1,ax2,ay2,bx1,by1,bx2,by2)
    ccw?(ax1, ay1, bx1, by1, bx2, by2) != ccw?(ax2, ay2, bx1, by1, bx2, by2) && ccw?(ax1, ay1, ax2, ay2, bx1, by1) != ccw?(ax1, ay1, ax2, ay2, bx2, by2)
  end

  # @param [Array<Float>] axes_x
  # @param [Array<Float>] axes_y
  # @param [Array<Float>] vert_ax
  # @param [Array<Float>] vert_ay
  # @param [Array<Float>] vert_bx
  # @param [Array<Float>] vert_by
  # @return [Boolean]
  def sat_intersect?(axes_x,axes_y,vert_ax,vert_ay, vert_bx,vert_by)
    index, limit = 0, axes_x.length
    while index < limit
      axis_x = axes_x[index]
      axis_y = axes_y[index]

      # Test to see if the polygons do *not* overlap on this axis.
      a_min, a_max = 1e300, -1e300
      jndex, jimit = 0, vert_ax.length
      while jndex < jimit
        tmp = axis_x * vert_ax[jndex] + axis_y * vert_ay[jndex]
        a_min = tmp if tmp < a_min
        a_max = tmp if tmp > a_max
        jndex += 1
      end
      b_min, b_max = 1e300, -1e300
      jndex, jimit = 0, vert_bx.length
      while jndex < jimit
        tmp = axis_x * vert_bx[jndex] + axis_y * vert_by[jndex]
        b_min = tmp if tmp < b_min
        b_max = tmp if tmp > b_max
        jndex += 1
      end

      return false if (a_min > b_max) || (b_min > a_max) # A separating axis exists. Thus, they cannot be intersecting.
      index += 1
    end
    true
  end

end

# Adds the MagicHelper sneakily, so it isn't listed in code completion.
# todo this is dumb
GeoGeo.const_set("MagicHelper", GeoGeoHelper.new) unless GeoGeo.const_defined?(:MagicHelper)
