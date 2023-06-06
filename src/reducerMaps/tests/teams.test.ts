/* eslint-env mocha */
/* eslint-disable no-unused-expressions */

import { expect } from "chai";
import { State, Team } from "../../interfaces";
import teams from "../teams";

describe("reducerMaps/teams", () => {
  describe("USER_DELETED", () => {
    let beforeState: State["teams"];
    let afterState: State["teams"];
    beforeEach(() => {
      beforeState = {
        didInvalidate: false,
        isFetching: false,
        items: {
          result: [77, 12345],
          entities: {
            77: {},
            12345: {},
          },
        },
      };
    });

    describe("when current user has not been deleted", () => {
      beforeEach(() => {
        afterState = teams(beforeState, {
          id: 2,
          isSelf: false,
          team: {
            id: 12345,
          } as Team,
          type: "USER_DELETED",
        });
      });

      it("does not modify state", () => {
        expect(afterState).to.eq(beforeState);
      });
    });

    describe("when current user has been deleted", () => {
      beforeEach(() => {
        afterState = teams(beforeState, {
          id: 1,
          isSelf: true,
          team: {
            id: 77,
          } as Team,
          type: "USER_DELETED",
        });
      });

      it("removes team from list", () => {
        expect(afterState.items.result).to.have.length(1);
      });
    });
  });
});
