/**
 * React Starter Kit (https://www.reactstarterkit.com/)
 *
 * Copyright © 2014-2016 Kriasoft, LLC. All rights reserved.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE.txt file in the root directory of this source tree.
 */

const actions = [
  'SORT_RESTAURANTS',
  'INVALIDATE_RESTAURANTS',
  'POST_RESTAURANT',
  'RESTAURANT_POSTED',
  'DELETE_RESTAURANT',
  'RESTAURANT_DELETED',
  'RENAME_RESTAURANT',
  'RESTAURANT_RENAMED',
  'REQUEST_RESTAURANTS',
  'RECEIVE_RESTAURANTS',
  'POST_DECISION',
  'DECISION_POSTED',
  'DELETE_DECISION',
  'DECISION_DELETED',
  'FLASH_ERROR',
  'EXPIRE_FLASH',
  'NOTIFY',
  'EXPIRE_NOTIFICATION',
  'POST_VOTE',
  'VOTE_POSTED',
  'DELETE_VOTE',
  'VOTE_DELETED',
  'SHOW_INFO_WINDOW',
  'HIDE_INFO_WINDOW',
  'HIDE_ALL_INFO_WINDOWS',
  'CLEAR_CENTER',
  'CREATE_TEMP_MARKER',
  'CLEAR_TEMP_MARKER',
  'SET_SHOW_UNVOTED',
  'SHOW_ADD_TAG_FORM',
  'HIDE_ADD_TAG_FORM',
  'SET_ADD_TAG_AUTOSUGGEST_VALUE',
  'SHOW_EDIT_NAME_FORM',
  'HIDE_EDIT_NAME_FORM',
  'SET_EDIT_NAME_FORM_VALUE',
  'POST_NEW_TAG_TO_RESTAURANT',
  'POSTED_NEW_TAG_TO_RESTAURANT',
  'POST_TAG_TO_RESTAURANT',
  'POSTED_TAG_TO_RESTAURANT',
  'DELETE_TAG_FROM_RESTAURANT',
  'DELETED_TAG_FROM_RESTAURANT',
  'SHOW_MODAL',
  'HIDE_MODAL',
  'DELETE_TAG',
  'TAG_DELETED',
  'SHOW_TAG_FILTER_FORM',
  'HIDE_TAG_FILTER_FORM',
  'SET_TAG_FILTER_AUTOSUGGEST_VALUE',
  'ADD_TAG_FILTER',
  'REMOVE_TAG_FILTER',
  'SHOW_TAG_EXCLUSION_FORM',
  'HIDE_TAG_EXCLUSION_FORM',
  'SET_TAG_EXCLUSION_AUTOSUGGEST_VALUE',
  'ADD_TAG_EXCLUSION',
  'REMOVE_TAG_EXCLUSION',
  'POST_WHITELIST_EMAIL',
  'WHITELIST_EMAIL_POSTED',
  'DELETE_WHITELIST_EMAIL',
  'WHITELIST_EMAIL_DELETED',
  'SET_EMAIL_WHITELIST_INPUT_VALUE',
  'SCROLL_TO_TOP',
  'SCROLLED_TO_TOP'
];

const actionMap = {};

actions.forEach(action => {
  actionMap[action] = action;
});

export default actionMap;
