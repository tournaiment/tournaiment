module Operator
  class BaseController < ApplicationController
    before_action :require_operator_session!
  end
end
