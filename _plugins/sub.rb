module Jekyll
  class SubConverter < Converter
    safe true
    priority :highest

    def matches(ext)
      ext =~ /^\.md$/i
    end

    def output_ext(ext)
      ".md"
    end

    def convert(content)
      convContent = content.gsub(/\^\> (.*?)(?:([\r\n])| \<\^)/, "<sub>\\1</sub>\\2")
      if convContent == content then
          return content
      else
          return convert(convContent)
      end
    end
  end
end