require 'rails_helper'

RSpec.describe LettersOfCreditPolicy, :type => :policy do
  let(:user) { instance_double(User, id: double('User ID'), member: nil) }
  let(:letter_of_credit_request) { instance_double(LetterOfCreditRequest) }
  let(:beneficiary_request) { instance_double(BeneficiaryRequest) }

  describe '`request?` method' do
    subject { LettersOfCreditPolicy.new(user, :letter_of_credit) }

    context 'for an intranet user' do
      before { allow(user).to receive(:intranet_user?).and_return(true) }

      it { should permit_action(:request) }
    end
    context 'for a non-intranet user' do
      before { allow(user).to receive(:intranet_user?).and_return(false) }

      context 'for a signer' do
        before do
          allow(user).to receive(:roles).and_return([User::Roles::ADVANCE_SIGNER])
        end
        it { should permit_action(:request) }
      end

      context 'for a non-signer' do
        before do
          allow(user).to receive(:roles).and_return([])
        end
        it { should_not permit_action(:request) }
      end
    end
  end

  [:execute, :amend_execute].each do |method|
    describe '`#{method}` method' do
      subject { LettersOfCreditPolicy.new(user, :letter_of_credit) }

      context 'for an intranet user' do
        before { allow(user).to receive(:intranet_user?).and_return(true) }

        it { should_not permit_action(method) }
      end
      context 'for a non-intranet user' do
        before { allow(user).to receive(:intranet_user?).and_return(false) }

        context 'for a signer' do
          before do
            allow(user).to receive(:roles).and_return([User::Roles::ADVANCE_SIGNER])
          end
          it { should permit_action(method) }
        end

        context 'for a non-signer' do
          before do
            allow(user).to receive(:roles).and_return([])
          end
          it { should_not permit_action(method) }
        end
      end
    end
  end

  describe '`modify?` method' do
    subject { LettersOfCreditPolicy.new(user, letter_of_credit_request) }
    before do
      allow(letter_of_credit_request).to receive(:owners).and_return(Set.new)
    end
    it 'returns true if the user is an owner of the letter of credit request' do
      letter_of_credit_request.owners.add(user.id)
      expect(subject).to permit_action(:modify)
    end

    it 'returns false if the user is not an owner of the letter of credit request' do
      expect(subject).to_not permit_action(:modify)
    end
  end

  describe '`add_beneficiary?` method' do
    subject { LettersOfCreditPolicy.new(user, beneficiary_request) }
    before do
      allow(beneficiary_request).to receive(:owners).and_return(Set.new)
    end
    it 'returns true if the user is an owner of the beneficiary request' do
      beneficiary_request.owners.add(user.id)
      expect(subject).to permit_action(:add_beneficiary)
    end
    it 'returns false if the user is not an owner of the beneficiary request' do
      expect(subject).to_not permit_action(:add_beneficiary)
    end
  end
end