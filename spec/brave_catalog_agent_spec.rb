require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::BraveCatalogAgent do
  before(:each) do
    @valid_options = Agents::BraveCatalogAgent.new.default_options
    @checker = Agents::BraveCatalogAgent.new(:name => "BraveCatalogAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
