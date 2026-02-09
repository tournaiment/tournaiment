require "test_helper"

class OperatorOtpServiceTest < ActiveSupport::TestCase
  test "issues and verifies login OTP" do
    operator, = create_operator_account
    service = OperatorOtpService.new

    code = service.issue!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "123456"
    )
    assert_equal "123456", code

    result = service.verify!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "123456"
    )
    assert result.success?
  end

  test "invalid otp fails and increments attempts" do
    operator, = create_operator_account
    service = OperatorOtpService.new
    service.issue!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "123456"
    )

    result = service.verify!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "000000"
    )
    assert_not result.success?
    assert_equal :invalid_code, result.reason

    otp = operator.operator_one_time_passcodes.order(:created_at).last
    assert_equal 1, otp.attempt_count
  end

  test "expired otp fails" do
    operator, = create_operator_account
    service = OperatorOtpService.new
    service.issue!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "123456"
    )
    otp = operator.operator_one_time_passcodes.order(:created_at).last
    otp.update!(expires_at: 1.second.ago)

    result = service.verify!(
      operator_account: operator,
      purpose: OperatorOneTimePasscode::PURPOSE_LOGIN,
      code: "123456"
    )
    assert_not result.success?
    assert_equal :expired, result.reason
  end
end
