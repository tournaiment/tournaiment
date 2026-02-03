module Admin
  class HomeController < ApplicationController
    before_action :require_admin!

    def index
    end
  end
end
