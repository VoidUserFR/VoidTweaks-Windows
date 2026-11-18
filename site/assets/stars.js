// sprinkle a twinkling star field into #stars
(function(){
  var host=document.getElementById('stars'); if(!host) return;
  var n=Math.min(170, Math.round(window.innerWidth*window.innerHeight/12000));
  var html='';
  for(var i=0;i<n;i++){
    var big=Math.random()>.82, sz=big?(Math.random()>.6?3:2):(Math.random()>.9?2:1);
    var o=(0.12+Math.random()*0.5).toFixed(2);
    html+='<span class="s'+(big&&Math.random()>.6?' g':'')+'" style="left:'+(Math.random()*100).toFixed(2)
      +'%;top:'+(Math.random()*100).toFixed(2)+'%;width:'+sz+'px;height:'+sz+'px;opacity:'+o
      +';--d:'+(2.5+Math.random()*5).toFixed(2)+'s;animation-delay:'+(-Math.random()*6).toFixed(2)+'s"></span>';
  }
  host.innerHTML=html;
})();
