RSpec.shared_examples 'a user required action' do |method, action, params=nil|
  describe 'unauthenticated access' do
      it 'should redirect to the sign in page' do
        sign_out :user
        expect{self.send(method, action, params)}.to throw_symbol(:warden)
      end
    end
end

RSpec.shared_examples 'a user not required action' do |method, action, params=nil|
  describe 'unauthenticated access' do
      it 'should not redirect to the sign in page' do
        sign_out :user
        expect{self.send(method, action, params)}.to_not throw_symbol(:warden)
      end
    end
end