// WadeMoney 공유 데이터 — 가계부 앱과 App 컴포넌트가 함께 사용
window.WadeData = {
  cats: [
    { key:'food',    name:'식비', icon:'restaurant',       color:'#E28A4E' },
    { key:'cafe',    name:'카페', icon:'local_cafe',        color:'#C4924E' },
    { key:'bus',     name:'교통', icon:'directions_bus',    color:'#6F9FD8' },
    { key:'shop',    name:'쇼핑', icon:'shopping_bag',      color:'#DB84AE' },
    { key:'culture', name:'문화', icon:'movie',             color:'#D8AE45' },
    { key:'medical', name:'의료', icon:'medical_services',  color:'#5DB794' },
    { key:'house',   name:'주거', icon:'home',              color:'#8E82CE' },
    { key:'etc',     name:'기타', icon:'category',          color:'#A69B8C' },
  ],
  groups: [
    { date:'7월 15일', tag:'오늘', items:[
      { name:'지하철', catKey:'bus', amount:1400, time:'19:40' },
      { name:'편의점 간식', catKey:'etc', amount:3600, time:'18:05' },
      { name:'투썸 라떼', catKey:'cafe', amount:3200, time:'16:10' },
      { name:'스타벅스 아메리카노', catKey:'cafe', amount:4800, time:'14:20' },
      { name:'점심 김치찌개', catKey:'food', amount:9000, time:'12:30' },
      { name:'지하철', catKey:'bus', amount:1400, time:'09:10' },
    ]},
    { date:'7월 14일', tag:'어제', items:[
      { name:'마트 장보기', catKey:'food', amount:43200, time:'20:15' },
      { name:'넷플릭스', catKey:'culture', amount:13500, time:'11:00' },
      { name:'커피빈', catKey:'cafe', amount:5500, time:'09:30' },
    ]},
    { date:'7월 13일', items:[
      { name:'무신사 티셔츠', catKey:'shop', amount:39000, time:'21:40' },
      { name:'택시', catKey:'bus', amount:8700, time:'23:10' },
      { name:'아메리카노', catKey:'cafe', amount:4800, time:'15:20' },
    ]},
    { date:'7월 12일', items:[
      { name:'병원 진료', catKey:'medical', amount:12000, time:'10:30' },
      { name:'점심 파스타', catKey:'food', amount:11000, time:'12:50' },
      { name:'편의점', catKey:'etc', amount:2400, time:'16:00' },
    ]},
    { date:'7월 11일', items:[
      { name:'이마트 장보기', catKey:'food', amount:51000, time:'19:00' },
      { name:'CGV 영화', catKey:'culture', amount:15000, time:'20:30' },
      { name:'아메리카노', catKey:'cafe', amount:4800, time:'13:15' },
    ]},
    { date:'7월 10일', items:[
      { name:'중고거래 판매', catKey:null, income:true, amount:45000, time:'17:20' },
    ]},
  ],
  usage: { food:312000, cafe:168000, bus:88000, shop:145000, culture:62000, medical:45000, house:0, etc:71000 },
};
