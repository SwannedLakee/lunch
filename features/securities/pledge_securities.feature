@flip-on-securities
Feature: Pledge Securities
  As a user
  I want to pledge new securities

Background:
  Given I am logged in

@jira-mem-1678
Scenario: View the pledge securities page
  When I am on the manage securities page
  And I click the button to create a new pledge request
  Then I should be on the pledge securities page

@jira-mem-2070
Scenario: View the pledge securities page from the nav
  When I click on the securities link in the header
  And I click on the pledge new link in the header
  Then I should be on the pledge securities page

@jira-mem-1678
Scenario: Member views the broker instructions
  When I am on the pledge securities page
  Then I should see "SBC" as the selected pledge type

@jira-mem-1678
Scenario: View the various Delivery Instructions field sets
  When I am on the pledge securities page
  Then I should see "DTC" as the selected release delivery instructions
  And I should see the "DTC" release instructions fields
  When I select "Fed" as the release delivery instructions
  Then I should see "Fed" as the selected release delivery instructions
  And I should see the "Fed" release instructions fields
  When I select "Physical" as the release delivery instructions
  Then I should see "Physical" as the selected release delivery instructions
  And I should see the "Physical" release instructions fields
  When I select "Mutual Fund" as the release delivery instructions
  Then I should see "Mutual Fund" as the selected release delivery instructions
  And I should see the "Mutual Fund" release instructions fields

@jira-mem-1678
Scenario: Member cannot click on the account number input
  Given I am on the pledge securities page
  Then the Pledge Account Number should be disabled

@jira-mem-1669
Scenario: A signer views a previously submitted pledge request
  Given I am logged in as a "quick-advance signer"
  And I am on the securities request page
  When I click to Authorize the first pledge intake
  Then I should be on the Pledge Securities page