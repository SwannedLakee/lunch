@jira-mem-69
Feature: Visiting the Account Summary Page
  As a user
  I want to use visit the account summary page for the FHLB Member Portal
  In order to find out an overall picture of my banks position

  Background:
    Given I am logged in

@smoke @jira-mem-727
Scenario: Visit account summary report page from header link
  Given I visit the dashboard
  When I select "Account Summary" from the reports dropdown
  And I wait for the report to load
  Then I should see 6 report tables with multiple data rows
  And I should see a report header with just freshness

@data-unavailable @jira-mem-727
Scenario: The Account Summary has been disabled
  Given I am on the "Account Summary" report page
  When the "Account Summary" report has been disabled
  Then I should see 6 report tables with multiple data rows
  And I should see the Financing Availablity table 

@jira-mem-826 @resque-backed @smoke
Scenario: Member downloads a PDF of the Account Summary report
  Given I am on the "Account Summary" report page
  When I request a PDF
  Then I should begin downloading a file

@jira-mem-1771 @data-unavailable
Scenario: Users don't see Financing Availablity if its disabled
  Given the Finanancing Availability data source has been disabled
  When I am on the "Account Summary" report page
  Then I should not see the Financing Availablity table
  And I should see 5 report tables with multiple data rows
