// config/webpack/rules/vue.js
const { VueLoaderPlugin } = require('vue-loader')

module.exports = {
  module: {
    rules: [
      {
        test: /\.vue$/,
        loader: 'vue-loader',
        options: {
          compilerOptions: {
            compatConfig: {
              MODE: 2
            }
          }
        },
      },
    ]
  },
  plugins: [new VueLoaderPlugin()],
  resolve: {
    extensions: ['.vue'],
    alias: {
      vue: '@vue/compat'
    },
  }
}
