import update from 'immutability-helper';
import ActionTypes from '../constants/ActionTypes';
import { getTagIds, getTagById } from '../selectors/tags';
import isFetching from './helpers/isFetching';

export default new Map([
  [ActionTypes.POSTED_TAG_TO_RESTAURANT, (state, action) =>
    update(state, {
      items: {
        entities: {
          tags: {
            [action.id]: {
              restaurant_count: {
                $set: parseInt(getTagById({ tags: state }, action.id).restaurant_count, 10) + 1
              }
            }
          }
        }
      }
    })
  ],
  [ActionTypes.POSTED_NEW_TAG_TO_RESTAURANT, (state, action) =>
    update(state, {
      items: {
        result: {
          $push: [action.tag.id]
        },
        entities: {
          tags: {
            $merge: {
              [action.tag.id]: action.tag
            }
          }
        }
      }
    })
  ],
  [ActionTypes.DELETED_TAG_FROM_RESTAURANT, (state, action) =>
    update(state, {
      isFetching: {
        $set: false
      },
      items: {
        entities: {
          tags: {
            [action.id]: {
              $merge: {
                restaurant_count:
                  parseInt(state.items.entities.tags[action.id].restaurant_count, 10) - 1
              }
            }
          }
        }
      }
    })
  ],
  [ActionTypes.DELETE_TAG, isFetching],
  [ActionTypes.TAG_DELETED, (state, action) =>
    update(state, {
      isFetching: {
        $set: false
      },
      items: {
        result: {
          $splice: [[getTagIds({ tags: state }).indexOf(action.id), 1]]
        }
      }
    })
  ]
]);
