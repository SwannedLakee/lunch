export default (user, team) => {
  if (!team) {
    return undefined;
  }
  if (user.type) {
    return { type: user.type };
  }
  return user.roles.find(userRole => userRole.teamId === team.id);
};
