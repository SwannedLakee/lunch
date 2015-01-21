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
          api do
            key :path, "/{id}/capital_stock_balance/{balance_date}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve Capital Stock Balance for a specific date for a member'
              key :notes, 'Returns Capital Stock Balance and Open/Close balance for the selected date.'
              key :type, :CapitalStockBalance
              key :nickname, :getCapitalStockBalanceForMember
              parameter do
                key :paramType, :path
                key :name, :id
                key :required, true
                key :type, :string
                key :description, 'The id to find the members from'
              end
              parameter do
                key :paramType, :path
                key :name, :balance_date
                key :required, true
                key :type, :string
                key :description, 'Start date yyyy-mm-dd for the Capital Stock Activities Report.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
              response_message do
                key :code, 400
                key :message, 'Invalid input'
              end
          end
          end
          api do
            key :path, "/{id}/capital_stock_activities/{from_date}/{to_date}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve Capital Stock Activities transactions.'
              key :notes, 'Returns Capital Stock Activities for the selected periord.'
              key :type, :CapitalStockActivities
              key :nickname, :getCapitalStockActivitiesForMember
              parameter do
                key :paramType, :path
                key :name, :id
                key :required, true
                key :type, :string
                key :description, 'The id to find the members from'
              end
              parameter do
                key :paramType, :path
                key :name, :from_date
                key :required, true
                key :type, :string
                key :description, 'Start date yyyy-mm-dd for the Capital Stock Activities Report.'
              end
              parameter do
                key :paramType, :path
                key :name, :to_date
                key :required, true
                key :type, :string
                key :description, 'End date yyyy-mm-dd for the Capital Stock Activities Report.'
              end
              response_message do
                key :code, 200
                key :message, 'OK'
              end
              response_message do
                key :code, 400
                key :message, 'Invalid input'
              end
            end
          end

          api do
            key :path, "/{id}/borrowing_capacity_details/{as_of_date}"
            operation do
              key :method, 'GET'
              key :summary, 'Retrieve Borrowing Capacity details for both Standard and SBC'
              key :notes, 'Returns Borrowing Capacity details values for Standard (which also include collateral type breakdown) and SBC.'
              key :type, :BorrowingCapacityDetails
              key :nickname, :getBorrowingCapactityDetailsForMember
              parameter do
                key :paramType, :path
                key :name, :id
                key :required, true
                key :type, :integer
                key :description, 'The id to find the members from'
              end
              parameter do
                key :paramType, :path
                key :name, :as_of_date
                key :defaultValue,  Date.today()
                key :required, true
                key :type, :date
                key :description, 'As of date for the Borrowing Capacity data.  If not provided, will retrieve intraday position.'
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
            WHERE fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
            GROUP BY fhlb_id
          SQL

          securities_connection_string = <<-SQL
            SELECT
            NVL(V_CONFIRM_SUMMARY_INTRADAY.SBC_MV_AG,0) AS agency_mv,
            NVL(V_CONFIRM_SUMMARY_INTRADAY.SBC_MV_AAA,0) AS aaa_mv,
            NVL(V_CONFIRM_SUMMARY_INTRADAY.SBC_MV_AA,0) AS aa_mv
            FROM V_CONFIRM_SUMMARY_INTRADAY@COLAPROD_LINK.WORLD
            WHERE fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
          SQL

          if settings.environment == :production
            mortages_cursor = ActiveRecord::Base.connection.execute(mortgages_connection_string)
            securities_cursor = ActiveRecord::Base.connection.execute(securities_connection_string)
            mortgage_mv, agency_mv, aaa_mv, aa_mv = 0
            while row = mortages_cursor.fetch()
              mortgage_mv = row[0].to_i
              break
            end
            while row = securities_cursor.fetch()
              agency_mv = row[0].to_i
              aaa_mv = row[1].to_i
              aa_mv = row[2].to_i
              break
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
            WHERE account_type = 'U' AND fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
          SQL

          if settings.environment == :production
            pledged_securities_cursor = ActiveRecord::Base.connection.execute(pledged_securities_string)
            safekept_securities_cursor = ActiveRecord::Base.connection.execute(safekept_securities_string)
            pledged_securities, safekept_securities = 0
            while row = pledged_securities_cursor.fetch()
              pledged_securities = row[0].to_i
              break
            end
            while row = safekept_securities_cursor.fetch()
              safekept_securities = row[0].to_i
              break
            end
            {pledged_securities: pledged_securities, safekept_securities: safekept_securities}.to_json
          else
            File.read(File.join(MAPI.root, 'fakes', 'member_balance_total_securities.json'))
          end
        end

        relative_get "/:id/balance/effective_borrowing_capacity" do
          member_id = params[:id]
          borrowing_capacity_connection_string = <<-SQL
            SELECT (NVL(REG_BORR_CAP,0) +  NVL(SBC_BORR_CAP,0)) AS total_BC,
            (NVL(EXCESS_REG_BORR_CAP,0) + NVL(EXCESS_SBC_BORR_CAP,0)) AS unused_BC
            FROM CR_MEASURES.FINAN_SUMMARY_DATA_INTRADAY_V
            WHERE fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
          SQL

          if settings.environment == :production
            borrowing_capacity_cursor = ActiveRecord::Base.connection.execute(borrowing_capacity_connection_string)
            total_capacity, unused_capacity = 0
            while row = borrowing_capacity_cursor.fetch()
              total_capacity = row[0].to_i
              unused_capacity = row[1].to_i
              break
            end
            {
                total_capacity: total_capacity,
                unused_capacity: unused_capacity
            }.to_json
          else
            File.read(File.join(MAPI.root, 'fakes', 'member_balance_effective_borrowing_capacity.json'))
          end
        end
        # capital stock balance
        relative_get "/:id/capital_stock_balance/:balance_date" do
          member_id = params[:id]
          balance_date = params[:balance_date]

          #1.check that input for from and to dates are valid date and expected format
          check_date_format = balance_date.match(MAPI::Shared::Constants::REPORT_PARAM_DATE_FORMAT)
          if !check_date_format
            halt 400, "Invalid Start Date format of yyyy-mm-dd"
          end


          capstock_balance_open_connection_string = <<-SQL
            SELECT sum(no_share_holding) as open_balance_cf FROM capstock.capstock_shareholding
            WHERE fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
            AND (sold_date is null or sold_date >= to_date(#{ActiveRecord::Base.connection.quote(balance_date)}, 'yyyy-mm-dd') )
            AND purchase_date < to_date(#{ActiveRecord::Base.connection.quote(balance_date)}, 'yyyy-mm-dd')
            GROUP BY fhlb_id
          SQL

           capstock_balance_close_connection_string = <<-SQL
             SELECT sum(no_share_holding) as open_balance_cf FROM capstock.capstock_shareholding
             WHERE fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
             AND (sold_date is null or sold_date > to_date(#{ ActiveRecord::Base.connection.quote(balance_date)}, 'yyyy-mm-dd') )
             AND purchase_date <= to_date(#{ ActiveRecord::Base.connection.quote(balance_date)}, 'yyyy-mm-dd')
             GROUP BY fhlb_id
           SQL

          if settings.environment == :production
            cp_open_cursor = ActiveRecord::Base.connection.execute(capstock_balance_open_connection_string)
            cp_close_cursor = ActiveRecord::Base.connection.execute(capstock_balance_close_connection_string)
            open_balance = (cp_open_cursor.fetch() || [nil])[0]
            close_balance = (cp_close_cursor.fetch() || [nil])[0]

          else
            results = JSON.parse(File.read(File.join(MAPI.root, 'fakes', 'capital_stock_balances.json'))).with_indifferent_access
            open_balance = results[:open_balance]
            close_balance = results[:close_balance]
          end
          {
              open_balance: (open_balance || 0).to_f,
              close_balance: (close_balance || 0).to_f,
              balance_date: balance_date.to_date
          }.to_json
        end

        # capital stock activities
        relative_get "/:id/capital_stock_activities/:from_date/:to_date" do
          member_id = params[:id]
          from_date = params[:from_date]
          to_date = params[:to_date]
          [from_date, to_date].each do |date|
            check_date_format = date.match(MAPI::Shared::Constants::REPORT_PARAM_DATE_FORMAT)
            if !check_date_format
              halt 400, "Invalid Start Date format of yyyy-mm-dd"
            end
          end



          capstockactivities_transactions_connection_string = <<-SQL
          SELECT CERT_ID, NO_SHARE, TRAN_DATE, NVL(TRAN_TYPE, '-') TRAN_TYPE, NVL(DR_CR, '-') DR_CR
          FROM CAPSTOCK.ACCOUNT_ACTIVITY_V Vw
          WHERE fhlb_id = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
          AND tran_date >= to_date(#{ActiveRecord::Base.connection.quote(from_date)}, 'yyyy-mm-dd')
          AND tran_date <= to_date(#{ActiveRecord::Base.connection.quote(to_date)}, 'yyyy-mm-dd')
          SQL

          if settings.environment == :production
            cp_trans_cursor = ActiveRecord::Base.connection.execute(capstockactivities_transactions_connection_string)
            activities = []
            while row = cp_trans_cursor.fetch()
              hash = {"cert_id" => row[0],
                      "share_number" => row[1],
                      "trans_date" => row[2],
                      "trans_type" => row[3],
                      "dr_cr" => row[4]}
              activities.push(hash)
            end
          else
            results = JSON.parse(File.read(File.join(MAPI.root, 'fakes', 'capital_stock_activities.json')))
            activities = []
            to_date_obj = Date.parse(to_date)
            from_date_obj = Date.parse(from_date)
            results["Activities"].each do |activity|
                  hash = {"cert_id" => activity["cert_id"],
                      "share_number" => activity["share_number"],
                      "trans_date" => Date.parse(activity["trans_date"]),
                      "trans_type" => activity["trans_type"],
                      "dr_cr" => activity["dr_cr"]
                      }
              activities.push(hash) if hash["trans_date"] >= from_date_obj && hash["trans_date"] <= to_date_obj
            end
          end
          activities_formatted = []
          activities.each do |row|
            hash = {"cert_id" => row["cert_id"].to_s,
                    "share_number" => row["share_number"].to_f,
                    "trans_date" => row["trans_date"].to_date,
                    "trans_type" => row["trans_type"].to_s,
                    "dr_cr" => row["dr_cr"].to_s
            }
            activities_formatted.push(hash)
          end
          {
            activities: activities_formatted
          }.to_json
        end

        # Borrowing Capacity Details
        relative_get "/:id/borrowing_capacity_details/:as_of_date" do
          member_id = params[:id]
          as_of_date = params[:as_of_date]

          #1.check that input date if provided to be valid date and expected format.
          if as_of_date.length > 0
            check_date_format = as_of_date.match(MAPI::Shared::Constants::REPORT_PARAM_DATE_FORMAT)
            if !check_date_format
              halt 400, "Invalid Start Date format of yyyy-mm-dd"
            end
          end

          # ASSUMPTION is always get current position.  The Date param is for future use when allow historical data

          bc_balances_connection_string = <<-SQL
            SELECT UPDATE_DATE, STD_EXCL_BL_BC, STD_EXCL_BANK_BC, STD_EXCL_REG_BC, STD_SECURITIES_BC, STD_ADVANCES, STD_LETTERS_CDT_USED,
            STD_SWAP_COLL_REQ, STD_COVER_OTHER_PT_DEF, STD_PREPAY_FEES, STD_OTHER_COLL_REQ, STD_MPF_CE_COLL_REQ, STD_COLL_EXCESS_DEF,
            SBC_MV_AA, SBC_BC_AA, SBC_ADVANCES_AA, SBC_COVER_OTHER_AA, SBC_MV_COLL_EXCESS_DEF_AA, SBC_COLL_EXCESS_DEF_AA,
            SBC_MV_AAA, SBC_BC_AAA, SBC_ADVANCES_AAA, SBC_COVER_OTHER_AAA, SBC_MV_COLL_EXCESS_DEF_AAA, SBC_COLL_EXCESS_DEF_AAA,
            SBC_MV_AG, SBC_BC_AG, SBC_ADVANCES_AG, SBC_COVER_OTHER_AG, SBC_MV_COLL_EXCESS_DEF_AG, SBC_COLL_EXCESS_DEF_AG,
            SBC_OTHER_COLL_REQ, SBC_COLL_EXCESS_DEF, STD_TOTAL_BC, SBC_BC, SBC_MV, SBC_ADVANCES, SBC_MV_COLL_EXCESS_DEF
            FROM V_CONFIRM_SUMMARY_INTRADAY@COLAPROD_LINK.WORLD
            WHERE FHLB_ID = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
          SQL

          bc_std_breakdown_string = <<-SQL
            SELECT COLLATERAL_TYPE, STD_COUNT, STD_UNPAID_BALANCE, STD_BORROWING_CAPACITY,
            STD_ORIGINAL_AMOUNT, STD_MARKET_VALUE, COLLATERAL_SORT_ID
            FROM V_CONFIRM_DETAIL@COLAPROD_LINK.WORLD
            WHERE FHLB_ID = #{ActiveRecord::Base.connection.quote(member_id.to_i)}
            ORDER BY COLLATERAL_SORT_ID
          SQL

          # set the expected balances value to 0 just in case it is not found, want to return 0 values
          balance_hash = {}
          std_breakdown= []
          if settings.environment == :production
            bc_balances_cursor = ActiveRecord::Base.connection.execute(bc_balances_connection_string)
            while row = bc_balances_cursor.fetch_hash()
              balance_hash = row
              break
            end
            bc_std_breakdown_cursor = ActiveRecord::Base.connection.execute(bc_std_breakdown_string)
            while row = bc_std_breakdown_cursor.fetch_hash()
              std_breakdown.push(row)
            end
          else
            balance_hash = JSON.parse(File.read(File.join(MAPI.root, 'fakes', 'borrowing_capacity_balances.json')))
            std_breakdown = JSON.parse(File.read(File.join(MAPI.root, 'fakes', 'borrowing_capacity_std_breakdown.json')))
          end
          standard_breakdown_formatted = []

          std_breakdown.each do |row|
            reformat_hash = {'type' => row['COLLATERAL_TYPE'],
                    'count' => row['STD_COUNT'],
                    'original_amount' => (row['STD_ORIGINAL_AMOUNT'] || 0).to_f.round,
                    'unpaid_principal' => (row['STD_UNPAID_BALANCE'] || 0).to_f.round,
                    'market_value' => (row['STD_MARKET_VALUE'] || 0).to_f.round,
                    'borrowing_capacity' => (row['STD_BORROWING_CAPACITY'] || 0).to_f.round
            }
            standard_breakdown_formatted.push(reformat_hash)
          end
          # format the SBC into an array of hash
          sbc_breakdown = [
            { type: 'AA',
              total_market_value: (balance_hash['SBC_MV_AA'] || 0).to_f.round,
              total_borrowing_capacity: (balance_hash['SBC_BC_AA'] || 0).to_f.round,
              advances: (balance_hash['SBC_ADVANCES_AA'] || 0).to_f.round,
              standard_credit: (balance_hash['SBC_COVER_OTHER_AA'] || 0).to_f.round,
              remaining_market_value: (balance_hash['SBC_MV_COLL_EXCESS_DEF_AA'] || 0).to_f.round,
              remaining_borrowing_capacity: (balance_hash['SBC_COLL_EXCESS_DEF_AA'] || 0).to_f.round
            },
            { type: 'AAA',
              total_market_value: (balance_hash['SBC_MV_AAA'] || 0).to_f.round,
              total_borrowing_capacity: (balance_hash['SBC_BC_AAA'] || 0).to_f.round,
              advances: (balance_hash['SBC_ADVANCES_AAA'] || 0).to_f.round,
              standard_credit: (balance_hash['SBC_COVER_OTHER_AAA'] || 0).to_f.round,
              remaining_market_value: (balance_hash['SBC_MV_COLL_EXCESS_DEF_AAA'] || 0).to_f.round,
              remaining_borrowing_capacity: (balance_hash['SBC_COLL_EXCESS_DEF_AAA'] || 0).to_f.round
            },
            { type: 'Agency',
              total_market_value: (balance_hash['SBC_MV_AG'] || 0).to_f.round,
              total_borrowing_capacity: (balance_hash['SBC_BC_AG'] || 0).to_f.round,
              advances: (balance_hash['SBC_ADVANCES_AG'] || 0).to_f.round,
              standard_credit: (balance_hash['SBC_COVER_OTHER_AG'] || 0).to_f.round,
              remaining_market_value: (balance_hash['SBC_MV_COLL_EXCESS_DEF_AG'] || 0).to_f.round,
              remaining_borrowing_capacity: (balance_hash['SBC_COLL_EXCESS_DEF_AG'] || 0).to_f.round
            }
          ]

          {  date: as_of_date.to_date,
             standard: {
               collateral: standard_breakdown_formatted,
               excluded: {
                 blanket_lien: (balance_hash['STD_EXCL_BL_BC'] || 0).to_f.round,
                 bank: (balance_hash['STD_EXCL_BANK_BC'] || 0).to_f.round,
                 regulatory: (balance_hash['STD_EXCL_REG_BC'] || 0).to_f.round
                },
               utilized: {
                 advances: (balance_hash['STD_ADVANCES'] || 0).to_f.round,
                 letters_of_credit: (balance_hash['STD_LETTERS_CDT_USED'] || 0).to_f.round,
                 swap_collateral: (balance_hash['STD_SWAP_COLL_REQ'] || 0).to_f.round,
                 sbc_type_deficiencies: (balance_hash['STD_COVER_OTHER_PT_DEF'] || 0).to_f.round,
                 payment_fees: (balance_hash['STD_PREPAY_FEES'] || 0).to_f.round,
                 other_collateral: (balance_hash['STD_OTHER_COLL_REQ'] || 0).to_f.round,
                 mpf_ce_collateral: (balance_hash['STD_MPF_CE_COLL_REQ'] || 0).to_f.round
              }
             },
             sbc: {
                collateral: sbc_breakdown,
                utilized: {
                  other_collateral: (balance_hash['SBC_OTHER_COLL_REQ'] || 0).to_f.round,
                  excluded_regulatory: 0   # no matching data column in database
                }
              }
            }.to_json

        end
      end
    end
  end
end
