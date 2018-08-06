# frozen_string_literal: true

require 'scraped'

pages = [
  'https://minutes3.belfastcity.gov.uk/mgMemberIndex.aspx?FN=WARD&VW=LIST&PIC=0',
  'http://cardiff.moderngov.co.uk/mgMemberIndex.aspx?FN=WARD&VW=LIST&PIC=0'
]

class String
  def strip_any_whitespace
    # Including non-breaking spaces:
    gsub(/\A\p{Space}*(.*?)\p{Space}*\Z/, '\1')
  end
end

class MemberSummary < Scraped::HTML
  decorator Scraped::Response::Decorator::CleanUrls

  field :member_url do
    noko.at_css('a/@href').text
  end
end

class WardSection < Scraped::HTML
  field :ward_name do
    noko.text.strip_any_whitespace
  end

  field :member_summaries do
    noko.xpath('following-sibling::div[1]/ul/li').map do |li|
      fragment li => MemberSummary
    end
  end
end

class ByWardPage < Scraped::HTML
  field :wards do
    noko.css('.mgSectionTitle').map do |ward_heading|
      fragment ward_heading => WardSection
    end
  end
end

def domain_from_url(url)
  URI.parse(url).host.gsub(/^.*?([^\.]+\.gov\.uk)$/, '\1')
end

data = pages.flat_map do |page_url|
  page = ByWardPage.new(response: Scraped::Request.new(url: page_url).response)
  page.wards.flat_map do |ward|
    ward.member_summaries.map do |m|
      m.to_h.merge(ward_name: ward.ward_name).merge(domain: domain_from_url(page_url))
    end
  end
end

require 'pry'; binding.pry
