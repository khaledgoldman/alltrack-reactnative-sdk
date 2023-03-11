const path = require('path');

module.exports = {
  dependency: {
    platforms: {
      ios: {},
      android: {
        packageImportPath: 'import com.alltrack.nativemodule.AlltrackPackage;',
        packageInstance: 'new AlltrackPackage()',
      },
    },
  },
};
