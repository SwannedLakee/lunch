Feature: Visiting the Messages Page
  As a user
  I want to use visit the messages page for the FHLB Member Portal
  In order to view corporate communications

  Background:
    Given I am logged in

@smoke
Scenario: Visit the messages page from the header
  Given I visit the dashboard
  When I click on the messages icon in the header
  Then I should see "Categories" as the sidebar title
    And I should see a list of message categories in the sidebar
    And I should see "Messages" as the page's title

Scenario: Filtering by message type
  Given I am on the Messages Page
  When I select the "Investor Relations & Disclosure" filter in the sidebar
  Then I should see the active state for the "Investor Relations & Disclosure" sidebar item
  When I select the first message on the messages page
  Then I should see the active state for the "Investor Relations & Disclosure" sidebar item
  When I select the "Credit & Collateral" filter in the sidebar
  Then I should see the active state for the "Credit & Collateral" sidebar item
  When I select the first message on the messages page
  Then I should see the active state for the "Credit & Collateral" sidebar item

Scenario: View the details of a message
  Given I am on the Messages Page
  When I select the first message on the messages page
  Then I should be see the message detail view

Scenario: Navigate from one detail page to another
  Given I am on the Messages Page
  When I select the first message on the messages page
  Then I should be see the message detail view
    And I should remember the date of that message and its title
  When I click on the "Next" link at the top of the message detail view
  Then the date of the current message should be earlier than the date of the message I remembered and the title should be different
  When I click on the "Prior" link at the top of the message detail view
  Then I should see the date and the title of the message I remembered


