import LS from './local_storage'

const Mascots = {
  current: 0
};

function showMascot(cur) {
  const mascots = window.mascots;

  $('body').css("background-image", "url(" + mascots[cur][0] + ")");
  $('body').css("background-color", mascots[cur][1]);
  $('.mascotbox').css("background-image", "url(" + mascots[cur][0] + ")");
  $('.mascotbox').css("background-color", mascots[cur][1]);

  if (mascots[cur][2])
    $('#mascot_artist').html("Mascot by " + mascots[cur][2]);
  else
    $('#mascot_artist').html("&nbsp;");
}

function changeMascot() {
  const mascots = window.mascots;

  Mascots.current += 1;
  Mascots.current = Mascots.current % mascots.length;
  showMascot(Mascots.current);

  LS.put('mascot', Mascots.current);
}

function initMascots() {
  $('#change-mascot').on('click', changeMascot);
  const mascots = window.mascots;
  Mascots.current = parseInt(LS.get("mascot"));
  if (isNaN(Mascots.current) || Mascots.current < 0 || Mascots.current >= mascots.length)
    Mascots.current = Math.floor(Math.random() * mascots.length);
  showMascot(Mascots.current);
}

$(function () {
  if ($('#c-static > #a-home').length)
    initMascots();
});
