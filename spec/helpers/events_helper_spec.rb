# Copyright (c) 2016 Banff International Research Station.
# This file is part of Workshops. Workshops is licensed under
# the GNU Affero General Public License as published by the
# Free Software Foundation, version 3 of the License.
# See the COPYRIGHT file for details and exceptions.

require 'rails_helper'

describe EventsHelper, type: :helper do
  describe '#escape_stray_angle_brackets' do
    # Custom fields carry LaTeX from proposals. Without escaping, an HTML parser
    # reads "<x_1" as a tag and swallows the rest of the field as its attributes,
    # so everything after the first "<" disappears from the page.
    it 'keeps LaTeX that follows a bare "<"' do
      latex = '$$a=x_0<x_1<\cdots < x_n=b,$$ and the rest of the overview.'

      rendered = sanitize(helper.escape_stray_angle_brackets(latex))

      expect(rendered).to include('the rest of the overview')
      expect(rendered).to include('x_n=b')
    end

    it 'survives the full 26w5609 payload instead of truncating at the first "<"' do
      body = 'Intro. $$a=x_0' + (1..600).map { |i| "<x_#{i}" }.join(' ') +
             '<x_n=b$$ TRAILING_CONTENT.'

      rendered = sanitize(helper.escape_stray_angle_brackets(body))

      expect(rendered).to include('TRAILING_CONTENT')
    end

    # 72 of 933 production custom fields contain genuine <p>/<b>/<br>/<i>.
    # Escaping everything would render those as visible markup.
    it 'leaves real HTML markup working' do
      html = '<p>A paragraph with <b>bold</b> text.</p>'

      expect(sanitize(helper.escape_stray_angle_brackets(html)))
        .to eq('<p>A paragraph with <b>bold</b> text.</p>')
    end

    # The trap: b, i, p, a, sub and sup are allowed tags AND common math
    # variables, so a tag-name allowlist alone would eat "$a<b$" as bold.
    it 'does not mistake a comparison against a variable for an opening tag' do
      latex = 'we require $a<b$ and $c<i$ throughout'

      rendered = sanitize(helper.escape_stray_angle_brackets(latex))

      expect(rendered).to include('throughout')
      expect(rendered).to include('a&lt;b')
    end

    it 'escapes an unrecognised tag-like token but keeps the text after it' do
      rendered = sanitize(helper.escape_stray_angle_brackets('before <notatag> after'))

      expect(rendered).to include('before')
      expect(rendered).to include('after')
    end

    it 'handles blank and nil values' do
      expect(helper.escape_stray_angle_brackets(nil)).to eq('')
      expect(helper.escape_stray_angle_brackets('')).to eq('')
    end

    it 'does not double-escape content that is already escaped' do
      expect(helper.escape_stray_angle_brackets('a &lt;x_1 b')).to eq('a &lt;x_1 b')
    end
  end
end
