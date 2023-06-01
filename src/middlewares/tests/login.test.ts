/* eslint-env mocha */
/* eslint-disable no-unused-expressions */

import { expect } from "chai";
import { SinonSpy, SinonStub, match, spy, stub } from "sinon";
import { Response } from "superagent";
import request from "supertest";
import express, { Application, NextFunction, RequestHandler } from "express";
import proxyquire from "proxyquire";
import mockEsmodule from "../../../test/mockEsmodule";
import { MakeApp, User } from "../../interfaces";

const proxyquireStrict = proxyquire.noCallThru();

describe("middlewares/login", () => {
  let app: Application;
  let makeApp: MakeApp;
  let authenticateStub: SinonStub;

  beforeEach(() => {
    authenticateStub = stub().callsFake(
      (): RequestHandler => (req, res, next) => {
        req.user = { id: 1 } as User; // eslint-disable-line no-param-reassign
        next();
      }
    );
    makeApp = (deps, middleware) => {
      const loginMiddleware = proxyquireStrict("../login", {
        jsonwebtoken: mockEsmodule({
          default: {
            sign: () => "12345",
          },
        }),
        "../passport": mockEsmodule({
          default: {
            authenticate: authenticateStub,
          },
        }),
        "../config": mockEsmodule({
          auth: {
            jwt: {
              secret: "54321",
            },
          },
          bsHost: "lunch.pink",
        }),
        ...deps,
      }).default;

      const server = express();
      server.use((req, res, next) => {
        if (middleware) {
          middleware(req, res, next);
        } else {
          next();
        }
      });
      server.use("/", loginMiddleware());
      return server;
    };

    app = makeApp();
  });

  describe("GET /google", () => {
    describe("when on subdomain", () => {
      let response: Response;
      beforeEach((done) => {
        app = makeApp({}, (req, res, next) => {
          req.subdomain = "labzero"; // eslint-disable-line no-param-reassign
          next();
        });

        request(app)
          .get("/google")
          .then((r) => {
            response = r;
            done();
          });
      });

      it("returns 301", () => {
        expect(response.statusCode).to.eq(301);
      });

      it("redirects to root host with subdomain as query parameter", () => {
        expect(response.headers.location).to.eq(
          "http://lunch.pink/login/google?team=labzero"
        );
      });
    });

    describe("when team is in querystring", () => {
      beforeEach(() => request(app).get("/google?team=labzero"));

      it("adds team to state", () => {
        expect(
          authenticateStub.calledWith(
            "google",
            match({ state: JSON.stringify({ team: "labzero" }) })
          )
        ).to.be.true;
      });
    });
  });

  describe("GET /google/callback", () => {
    describe("when state is not in querystring", () => {
      let response: Response;
      beforeEach((done) => {
        request(app)
          .get("/google/callback")
          .then((r) => {
            response = r;
            done();
          });
      });

      it("returns 302", () => {
        expect(response.statusCode).to.eq(302);
      });

      it("redirects to root", () => {
        expect(response.headers.location).to.eq("/");
      });
    });

    describe("when state is in querystring", () => {
      let response: Response;
      beforeEach((done) => {
        request(app)
          .get('/google/callback?state={"team":"labzero"}')
          .then((r) => {
            response = r;
            done();
          });
      });

      it("returns 302", () => {
        expect(response.statusCode).to.eq(302);
      });

      it("redirects to subdomain", () => {
        expect(response.headers.location).to.eq("http://labzero.lunch.pink");
      });
    });
  });

  describe("POST /", () => {
    describe("when there is an error getting the user", () => {
      let flashSpy: SinonSpy;
      beforeEach(() => {
        authenticateStub = stub().callsFake(
          (strategy, options, callback) => () => {
            callback(null, false, { message: "Oh No" });
          }
        );
        flashSpy = spy();
        app = makeApp(
          {
            "../passport": mockEsmodule({
              default: {
                authenticate: authenticateStub,
              },
            }),
          },
          (req, res, next) => {
            req.flash = flashSpy; // eslint-disable-line no-param-reassign
            next();
          }
        );
        return request(app).post("/");
      });

      it("flashes error", () => {
        expect(flashSpy.calledWith("error", "Oh No")).to.be.true;
      });
    });

    describe("when there is no error", () => {
      let logInSpy: SinonSpy;
      let afterLoginNext: NextFunction;
      beforeEach(() => {
        authenticateStub = stub().callsFake(
          (strategy, options, callback): RequestHandler =>
            (req, res, next) => {
              afterLoginNext = next;
              callback(null, 1);
            }
        );
        logInSpy = spy(() => afterLoginNext());
        app = makeApp(
          {
            "../passport": mockEsmodule({
              default: {
                authenticate: authenticateStub,
              },
            }),
          },
          (req, res, next) => {
            req.logIn = logInSpy; // eslint-disable-line no-param-reassign
            next();
          }
        );
        return request(app).post("/");
      });

      it("calls logIn", () => {
        expect(logInSpy.callCount).to.eq(1);
      });
    });
  });
});
