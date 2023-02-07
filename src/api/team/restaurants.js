import { Router } from 'express';
import fetch from 'node-fetch';
import { Restaurant, Vote, Tag } from '../../models';
import checkTeamRole from '../helpers/checkTeamRole';
import loggedIn from '../helpers/loggedIn';
import { restaurantPosted, restaurantDeleted, restaurantRenamed } from '../../actions/restaurants';
import voteApi from './votes';
import restaurantTagApi from './restaurantTags';

export default () => {
  const router = new Router({ mergeParams: true });
  const apikey = process.env.GOOGLE_SERVER_APIKEY;

  const notFound = (res) => {
    res.status(404).json({ error: true, data: { message: 'Restaurant not found.' } });
  };

  return router
    .get(
      '/',
      loggedIn,
      checkTeamRole(),
      async (req, res, next) => {
        try {
          const all = await Restaurant.findAllWithTagIds({ team_id: req.team.id });

          res.status(200).json({ error: false, data: all });
        } catch (err) {
          next(err);
        }
      }
    ).get(
      '/:id/place_url',
      loggedIn,
      checkTeamRole(),
      async (req, res, next) => {
        try {
          const r = await Restaurant.findById(parseInt(req.params.id, 10));

          if (r === null || r.team_id !== req.team.id) {
            notFound(res);
          } else {
            const response = await fetch(`https://maps.googleapis.com/maps/api/place/details/json?key=${apikey}&placeid=${r.place_id}`);
            const json = await response.json();
            if (response.ok) {
              if (json.status !== 'OK') {
                const newError = {
                  message: `Could not get info for restaurant. Google might have
removed its entry. Try removing it and adding it to Lunch again.`
                };
                res.status(404).json({ error: true, newError });
              } else if (json.result && json.result.url) {
                res.redirect(json.result.url);
              } else {
                res.redirect(`https://www.google.com/maps/place/${r.name}, ${r.address}`);
              }
            } else {
              next(json);
            }
          }
        } catch (err) {
          next(err);
        }
      }
    )
    .post(
      '/',
      loggedIn,
      checkTeamRole(),
      async (req, res, next) => {
        const {
          // eslint-disable-next-line camelcase
          name, place_id, lat, lng
        } = req.body;

        let { address } = req.body;
        address = address.replace(`${name}, `, '');

        try {
          const obj = await Restaurant.create({
            name,
            place_id,
            address,
            lat,
            lng,
            team_id: req.team.id,
            votes: [],
            tags: []
          }, { include: [Vote, Tag] });

          const json = obj.toJSON();
          json.all_decision_count = 0;
          json.all_vote_count = 0;
          req.wss.broadcast(req.team.id, restaurantPosted(json, req.user.id));
          res.status(201).send({ error: false, data: json });
        } catch (err) {
          const error = { message: 'Could not save new restaurant. Has it already been added?' };
          next(error);
        }
      }
    )
    .patch(
      '/:id',
      loggedIn,
      checkTeamRole(),
      async (req, res, next) => {
        const id = parseInt(req.params.id, 10);
        const { name } = req.body;

        Restaurant.update(
          { name },
          { fields: ['name'], where: { id, team_id: req.team.id }, returning: true }
        ).spread((count, rows) => {
          if (count === 0) {
            notFound(res);
          } else {
            const json = { name: rows[0].toJSON().name };
            req.wss.broadcast(req.team.id, restaurantRenamed(id, json, req.user.id));
            res.status(200).send({ error: false, data: json });
          }
        }).catch(() => {
          const error = { message: 'Could not update restaurant.' };
          next(error);
        });
      }
    )
    .delete(
      '/:id',
      loggedIn,
      checkTeamRole(),
      async (req, res, next) => {
        const id = parseInt(req.params.id, 10);
        try {
          const count = await Restaurant.destroy({ where: { id, team_id: req.team.id } });
          if (count === 0) {
            notFound(res);
          } else {
            req.wss.broadcast(req.team.id, restaurantDeleted(id, req.user.id));
            res.status(204).send();
          }
        } catch (err) {
          next(err);
        }
      }
    )
    .use('/:restaurant_id/votes', voteApi())
    .use('/:restaurant_id/tags', restaurantTagApi());
};
