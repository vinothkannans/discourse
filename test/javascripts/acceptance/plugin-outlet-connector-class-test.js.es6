import { acceptance } from "helpers/qunit-helpers";
import { extraConnectorClass, resetExtraClasses } from 'discourse/helpers/plugin-outlet';

const CONNECTOR = 'javascripts/single-test/connectors/user-profile-primary/class-test';

acceptance("Plugin Outlet - Class", {
  setup() {
    Ember.TEMPLATES[CONNECTOR] = Ember.HTMLBars.compile(
      `{{log this}}<span class='test-class-span'>{{model.username}}</span>`
    );

    // Note: in a plugin you can create a file to have this automatically wired up
    // javascripts/single-test/connectors/user-profile-primary/class-test.js.es6
    extraConnectorClass('user-profile-primary/class-test', {
      shouldRender() {
        // const username = this.get('model.username');
        // console.log(username);
        return true;
      }
    });
  },

  teardown() {
    delete Ember.TEMPLATES[CONNECTOR];
    resetExtraClasses();
  }
});

test("Renders a template into the outlet", assert => {
  visit("/users/eviltrout");
  andThen(() => {
    assert.ok(find('.user-profile-primary-outlet.class-test').length === 1, 'it has class names');
    assert.equal(find('.test-class-span').text(), 'eviltrout', 'it renders into the outlet');
  });
});
