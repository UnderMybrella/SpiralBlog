require 'jekyll'

class Inline < Liquid::Block
  def initialize(tag_name, markup, parse_context)
    super
    @markup = markup
  end

  def render(_context)
    _context['content'] = super
    @template = Liquid::Template.parse("{% include #{@markup} content=content %}")
    @template.render(_context)
  end

  Liquid::Template.register_tag 'inline', self
end