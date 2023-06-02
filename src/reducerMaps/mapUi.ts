import update, { Spec } from "immutability-helper";
import { Reducer } from "../interfaces";

const mapUi: Reducer<"mapUi"> = (state, action) => {
  switch (action.type) {
    case "RECEIVE_RESTAURANTS": {
      return update(state, {
        infoWindow: {
          $set: {},
        },
        showPOIs: {
          $set: !action.items.length,
        },
        showUnvoted: {
          $set: true,
        },
      });
    }
    case "RESTAURANT_POSTED": {
      return update(state, {
        newlyAdded: {
          $set: {
            id: action.restaurant.id,
            userId: action.userId,
          },
        },
      });
    }
    case "SHOW_GOOGLE_INFO_WINDOW": {
      return update(state, {
        center: {
          $set: {
            lat: action.latLng.lat,
            lng: action.latLng.lng,
          },
        },
        infoWindow: {
          $set: {
            latLng: action.latLng,
            placeId: action.placeId,
          },
        },
      });
    }
    case "SHOW_RESTAURANT_INFO_WINDOW": {
      return update(state, {
        center: {
          $set: {
            lat: action.restaurant.lat,
            lng: action.restaurant.lng,
          },
        },
        infoWindow: {
          $set: {
            id: action.restaurant.id,
          },
        },
      });
    }
    case "HIDE_INFO_WINDOW": {
      return update(state, {
        infoWindow: {
          $set: {},
        },
      });
    }
    case "SET_SHOW_POIS": {
      let updates = {
        showPOIs: {
          $set: action.val,
        },
      } as Spec<typeof state>;

      if (!action.val) {
        updates = {
          ...updates,
          infoWindow: {
            latLng: {
              $set: undefined,
            },
            placeId: {
              $set: undefined,
            },
          },
        };
      }

      return update(state, updates);
    }
    case "SET_SHOW_UNVOTED": {
      return update(state, {
        $merge: {
          showUnvoted: action.val,
        },
      });
    }
    case "SET_CENTER": {
      return update(state, {
        center: {
          $set: action.center,
        },
      });
    }
    case "CLEAR_CENTER": {
      return update(state, {
        center: {
          $set: undefined,
        },
      });
    }
    case "CREATE_TEMP_MARKER": {
      return update(state, {
        center: {
          $set: action.result.latLng,
        },
        tempMarker: {
          $set: action.result,
        },
      });
    }
    case "CLEAR_TEMP_MARKER": {
      return update(state, {
        center: {
          $set: undefined,
        },
        tempMarker: {
          $set: undefined,
        },
      });
    }
    case "CLEAR_MAP_UI_NEWLY_ADDED": {
      return update(state, {
        newlyAdded: {
          $set: undefined,
        },
      });
    }
    default:
      break;
  }
  return state;
};

export default mapUi;
