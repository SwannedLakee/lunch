module MAPI
  module Services
    module MemberBalance
      include MAPI::Services::Base

      def self.registered(app)
        service_root '/member', app
        swagger_api_root :member do

          # pledged collateral endpoint
          api do
            key :path, '/{id}/balance/pledged_collateral'
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve pledged collateral for member'
              key :notes, 'Returns an array of collateral pledged by a member broken down by security type'
              key :type, :MemberBalancePledgedCollateral
              key :nickname, :getPledgedCollateralForMember
              parameter do
                key :paramType, :path
                key :name, :id
                key :required, true
                key :type, :string
                key :description, 'The id to find the members from'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end

          # total securities endpoint
          api do
            key :path, '/{id}/balance/total_securities'
            operation do
              key :method, 'GET'
              key :summary, 'Retrieves counts of pledged and safekept securities for a member'
              key :notes, 'Returns an array containing a count of pledged and safekept securities'
              key :type, :MemberBalanceTotalSecurities
              key :nickname, :getTotalSecuritiesCountForMember
              parameter do
                key :paramType, :path
                key :name, :id
                key :required, true
                key :type, :string
                key :description, 'The id to find the members from'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end
          api do
            key :path, '/{id}/balance/effective_borrowing_capacity'
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve effective borrowing capacity for member'
              key :notes, 'Returns total and unused effective borrowing capacity for a member'
              key :type, :MemberBalanceBorrowingCapacity
              key :nickname, :memberBalanceEffectiveBorrowingCapacity
              parameter do
                key :paramType, :path
                key :name, :id
                key :required, true
                key :type, :string
                key :description, 'The id to find the members from'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
            end
          end
        end

        # pledged collateral route
        relative_get "/:id/balance/pledged_collateral" do
          member_id = params[:id]
          mortgages_connection_string = <<-SQL
            SELECT SUM(NVL(STD_MARKET_VALUE,0))
            FROM V_CONFIRM_DETAIL@COLAPROD_LINK.WORLD
            WHERE fhlb_id = #{member_id}
            GROUP BY fhlb_id
          SQL

          securities_connection_string = <<-SQL
            SELECT
            NVL(V_CONFIRM_SUMMARY_INTRADAY.SBC_MV_AG,0) AS agency_mv,
            NVL(V_CONFIRM_SUMMARY_INTRADAY.SBC_MV_AAA,0) AS aaa_mv,
            NVL(V_CONFIRM_SUMMARY_INTRADAY.SBC_MV_AA,0) AS aa_mv
            FROM V_CONFIRM_SUMMARY_INTRADAY@COLAPROD_LINK.WORLD
            WHERE fhlb_id =  #{member_id}
          SQL

          if settings.environment == :production
            mortages_cursor = ActiveRecord::Base.connection.execute(mortgages_connection_string)
            securities_cursor = ActiveRecord::Base.connection.execute(securities_connection_string)
            mortgage_mv, agency_mv, aaa_mv, aa_mv = 0
            while row = mortages_cursor.fetch()
              mortgage_mv = row[0]
            end
            while row = securities_cursor.fetch()
              agency_mv = row[0]
              aaa_mv = row[1]
              aa_mv = row[2]
            end
            {
              mortgages: mortgage_mv,
              agency: agency_mv,
              aaa: aaa_mv,
              aa: aa_mv
            }.to_json
          else
            File.read(File.join(MAPI.root, 'fakes', 'member_balance_pledged_collateral.json'))
          end
        end


        # total securities route
        relative_get "/:id/balance/total_securities" do
          member_id = params[:id]
          pledged_securities_string = <<-SQL
            SELECT COUNT(*)
            FROM SAFEKEEPING.SSK_INTRADAY_SEC_POSITION
            WHERE account_type = 'P' AND fhlb_id = #{member_id}
          SQL

          safekept_securities_string = <<-SQL
            SELECT COUNT(*)
            FROM SAFEKEEPING.SSK_INTRADAY_SEC_POSITION
            WHERE account_type = 'U' AND fhlb_id = #{member_id}
          SQL

          if settings.environment == :production
            pledged_securities_cursor = ActiveRecord::Base.connection.execute(pledged_securities_string)
            safekept_securities_cursor = ActiveRecord::Base.connection.execute(safekept_securities_string)
            pledged_securities, safekept_securities = 0
            while row = pledged_securities_cursor.fetch()
              pledged_securities = row[0]
            end
            while row = safekept_securities_cursor.fetch()
              safekept_securities = row[0]
            end
            {pledged_securities: pledged_securities, safekept_securities: safekept_securities}.to_json
          else
            File.read(File.join(MAPI.root, 'fakes', 'member_balance_total_securities.json'))
          end
      end
        relative_get "/:id/balance/effective_borrowing_capacity" do
          member_id = params[:id]
          borrowing_capacity_connection_string = <<-SQL
            SELECT (NVL(REG_BORR_CAP,0) +  NVL(SBC_BORR_CAP,0) AS total_BC,
            (NVL(EXCESS_REG_BORR_CAP,0) + NVL(EXCESS_SBC_BORR_CAP,0) AS unused_BC
            FROM CR_MEASURES.FINAN_SUMMARY_DATA_INTRADAY_V
            WHERE fhlb_id = #{member_id}
          SQL

          if settings.environment == :production
            borrowing_capacity_cursor = ActiveRecord::Base.connection.execute(borrowing_capacity_connection_string)
            total_capacity, unused_capacity = 0
            while row = borrowing_capacity_cursor.fetch()
              total_capacity = row[0]
              unused_capacity = row[1]
            end
            {
                total_capacity: total_capacity,
                unused_capacity: unused_capacity
            }.to_json
          else
            File.read(File.join(MAPI.root, 'fakes', 'member_balance_effective_borrowing_capacity.json'))
          end
        end
      end
    end
  end
end