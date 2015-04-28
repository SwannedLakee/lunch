@jira-mem-69
Feature: Visiting the Securities Transactions Report Page
  As a user
  I want to use visit the interest rate resets report page for the FHLB Member Portal
  In order to view securities transactions

Background:
  Given I am logged in

@smoke @jira-mem-410
Scenario: Visit securities transactions from header link
  Given I visit the dashboard
  When I select "Securities Transaction Report" from the reports dropdown
  Then I should see "Securities Transaction"
  And I should see a report table with multiple data rows

@smoke @jira-mem-410
Scenario: Visiting the Securities Transactions Report Page
  Given I am on the "Securities Transactions" report page
  Then I should see "Total Net Amount"
  And I should see Securities Transactions report

# NOTE: This is for fake data only, will change with MAPI
@smoke @jira-mem-410
Scenario: Visiting the Securities Transactions Report Page with new securities transaction
  Given I am on the "Securities Transactions" report page
  Then I should see a security that is indicated as a new transaction

@data-unavailable @jira-mem-410
Scenario: Visiting the Securities Transactions Report Page before the desk is closed
  Given I am on the "Securities Transactions" report page
  Then I should see "Preliminary Securities Transactions settled as of 11:30 a.m. on"

@data-unavailable @smoke @jira-mem-410
Scenario: Securities Transactions Report has been disabled
  Given I am on the "Securities Transactions" report page
  When the "Securities Transactions" report has been disabled
  Then I should see an empty report table with Data Unavailable messaging