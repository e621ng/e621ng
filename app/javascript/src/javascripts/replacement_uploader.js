const Replacer = {};

const thumbURLs = [
  "/images/notfound-preview.png",
  "data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="
];
const thumbs = {
  notfound: "/images/notfound-preview.png",
  none: 'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=='
};

Replacer.old_domain = "";

Replacer.update_preview_file = function (file) {
  const objectUrl = URL.createObjectURL(file);
  Replacer.set_preview_url(objectUrl);
};

Replacer.update_preview_url = function () {
  const url = $("#post_replacement_replacement_url").val();
  if (!url) {
    Replacer.upload_allow_clear();
    return;
  }

  const sampleURL = Replacer.isSampleURL(url);
  if (sampleURL !== false) {
    $('#bad_upload_url_reason').text(sampleURL);
    $('#bad_upload_url').show();
    return;
  } else {
    $('#bad_upload_url').hide();
  }

  const domain = $("<a>").prop("href", url).prop("hostname");
  if (domain && domain !== Replacer.old_domain) {
    $.getJSON("/upload_whitelists/is_allowed.json", {url: url}, function(data) {
      if(data.domain) {
        Replacer.upload_allow_set(data.is_allowed, data.domain, data.reason);
        if(!data.is_allowed)
          Replacer.set_preview_url(thumbs.none);
      }
    });
  } else if (!domain) {
    Replacer.upload_allow_clear();
  }
  Replacer.old_domain = domain;
  Replacer.set_preview_url(url);
};

Replacer.update_preview_dims = function () {
  const img = $('#replacement_preview_img')[0];
  if (thumbURLs.filter(function (x) {
    return img.src.indexOf(x) !== -1;
  }).length !== 0)
    return;
  Replacer.set_preview_dims(img.naturalHeight, img.naturalWidth);
};

Replacer.preview_error = function (e) {
  const img = e.target;
  Replacer.set_preview_dims(-1, -1);
  if (thumbURLs.filter(function (x) {
    return img.src.indexOf(x) !== -1;
  }).length !== 0)
    return;
  Replacer.set_preview_url(thumbs.notfound);
};

Replacer.set_preview_dims = function (height, width) {
  if (height <= 0 && width <= 0) {
    $('#replacement_preview_dims').text('');
  } else {
    $('#replacement_preview_dims').text(`${width}x${height}`);
  }
};

Replacer.set_preview_url = function (url) {
  $('#replacement_preview_img').attr('src', url);
};


Replacer.update_preview = function () {
  const $file = $("#post_replacement_replacement_file")[0];
  if ($file && $file.files[0])
    Replacer.update_preview_file($file.files[0]);
  else
    Replacer.update_preview_url();
}

Replacer.update_preview_paste = function () {
  setTimeout(Replacer.update_preview, 150);
}

Replacer.isSampleURL = function (url) {
  const patterns = [
    {reason: 'Thumbnail URL', test: /[at]\.facdn\.net/gi},
    {reason: 'Sample URL', test: /pximg\.net.*\/img-master\//gi},
    {reason: 'Sample URL', test: /d3gz42uwgl1r1y\.cloudfront\.net\/.*\/\d+x\d+\./gi},
    {reason: 'Sample URL', test: /pbs\.twimg\.com\/media\/[\w\-_]+\.(jpg|png)(:large)?$/gi},
    {reason: 'Sample URL', test: /pbs\.twimg\.com\/media\/[\w\-_]+\?format=(jpg|png)(?!&name=orig)/gi},
    {reason: 'Sample URL', test: /derpicdn\.net\/.*\/large\./gi},
    {reason: 'Sample URL', test: /metapix\.net\/files\/(preview|screen)\//gi},
    {reason: 'Sample URL', test: /sofurryfiles\.com\/std\/preview/gi}];
  for (let i = 0; i < patterns.length; ++i) {
    const pattern = patterns[i];
    if (pattern.test.test(url))
      return pattern.reason;
  }
  return false;
}

Replacer.upload_allow_clear = function() {
  $('#whitelist-warning').hide();
}

Replacer.upload_allow_set = function(allowed, domain, reason) {
  const classes = ['whitelist-warning-disallowed', 'whitelist-warning-allowed'];
  $('#whitelist-warning').removeClass().addClass(classes[allowed ? 1 : 0]);
  $('#whitelist-warning-domain').text(domain);
  if(allowed)
    $('#whitelist-warning-not').hide();
  else
    $('#whitelist-warning-not').show();
  $('#whitelist-warning').show();
}

Replacer.init_uploader = function () {
  $('#replacement_preview_img').on('load', Replacer.update_preview_dims);
  $('#replacement_preview_img').on('error', Replacer.preview_error);
  $('#post_replacement_replacement_url').on('keyup', Replacer.update_preview);
  $('#post_replacement_replacement_file').on('change', Replacer.update_preview);
  $('#post_replacement_replacement_url').on('paste', Replacer.update_preview_paste);
};

$(function () {
  if ($("#c-post-replacements > #a-new").length) {
    Replacer.init_uploader();
  }
});

export default Replacer;
