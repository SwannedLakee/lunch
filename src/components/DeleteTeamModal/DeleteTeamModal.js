import PropTypes from 'prop-types';
import React, { Component } from 'react';
import withStyles from 'isomorphic-style-loader/withStyles';
import Col from 'react-bootstrap/Col';
import Form from 'react-bootstrap/Form';
import InputGroup from 'react-bootstrap/InputGroup';
import Modal from 'react-bootstrap/Modal';
import ModalBody from 'react-bootstrap/ModalBody';
import ModalFooter from 'react-bootstrap/ModalFooter';
import Row from 'react-bootstrap/Row';
import Button from 'react-bootstrap/Button';
import { TEAM_SLUG_REGEX } from '../../constants';
import s from './DeleteTeamModal.scss';

class DeleteTeamModal extends Component {
  static propTypes = {
    host: PropTypes.string.isRequired,
    team: PropTypes.object.isRequired,
    shown: PropTypes.bool.isRequired,
    hideModal: PropTypes.func.isRequired,
    deleteTeam: PropTypes.func.isRequired,
  };

  state = {
    confirmSlug: '',
  };

  handleChange = (event) => {
    this.setState({
      confirmSlug: event.target.value,
    });
  };

  handleSubmit = () => {
    const { deleteTeam, host } = this.props;

    deleteTeam().then(() => {
      window.location.href = `//${host}/teams`;
    });
  };

  render() {
    const { team, shown, hideModal } = this.props;
    const { confirmSlug } = this.state;

    return (
      <Modal show={shown} onHide={hideModal}>
        <ModalBody>
          <p>
            Are you sure you want to delete the
            {' '}
            {team.name}
            {' '}
team?
            {' '}
            <strong>This is irreversible.</strong>
            {' '}
All restaurants and tags will
            be deleted, and all users will be unassigned from the team.
          </p>
          <p>
            To confirm, please write the URL of the team in the field below.
          </p>
          <Row>
            <Col sm={9}>
              <Form.Group className="mb-3" controlId="deleteTeamModal-confirmSlug">
                <Form.Label>Team URL</Form.Label>
                <InputGroup>
                  <Form.Control
                    className={s.teamUrl}
                    type="text"
                    onChange={this.handleChange}
                    pattern={TEAM_SLUG_REGEX}
                    value={confirmSlug}
                    required
                  />
                  <InputGroup.Text>.lunch.pink</InputGroup.Text>
                </InputGroup>
              </Form.Group>
            </Col>
          </Row>
        </ModalBody>
        <ModalFooter>
          <Button type="button" size="sm" onClick={hideModal}>
            Cancel
          </Button>
          <Button
            autoFocus
            size="sm"
            variant="primary"
            disabled={team.slug !== confirmSlug}
            onClick={this.handleSubmit}
            type="submit"
          >
            Delete
          </Button>
        </ModalFooter>
      </Modal>
    );
  }
}

export default withStyles(s)(DeleteTeamModal);
