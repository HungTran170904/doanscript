import moment from 'moment';
export const formatDate=(inputDate)=>{
          let d=moment(inputDate);
          return d.format('DD/MM/YYYY')
}

export const formatDateTime=(inputDateTime)=>{
          let d=moment(inputDateTime);
          return d.format('DD/MM/YYYY HH:mm:ss')
}

export const getDate = (inputDateTime) => {
    if (!inputDateTime) return null;
    let d = moment(inputDateTime);
    return d.format('YYYY-MM-DD');
}

export const getTime = (inputDateTime) => {
    if (!inputDateTime) return null;
    let d = moment(inputDateTime);
    return d.format('HH:mm:ss');
}
