import { API_ENDPOINT } from "../Util/Constraint";
import AxiosService from "../Util/AxiosService";

const adminUrl = '/admin';

export const addRegPeriod = (regPeriodData) => {
          return AxiosService.post(API_ENDPOINT + adminUrl + '/addRegPeriod',regPeriodData,true);
      }
      
      export const removeRegPeriod = (id) => {
          return AxiosService.delete(API_ENDPOINT + adminUrl + '/removeRegPeriod/' + id);
      }
      
      export const updateRegPeriod=(regPeriod)=>{
            return AxiosService.put(API_ENDPOINT + adminUrl + '/updateRegPeriod', regPeriod,true);
      }

      export const getAllRegperiods = () => {
          return AxiosService.get(API_ENDPOINT + adminUrl + '/getAllRegperiods');
      }

      export const getLatestSemesters=()=>{
        return AxiosService.get(API_ENDPOINT + adminUrl + '/getLatestSemesters');
      }

      export const getAllSemesters=()=>{
        return AxiosService.get(API_ENDPOINT + adminUrl + '/getAllSemesters');
      }
      
      export const addSemester = (semesterNum, year) => {
          let formData = new FormData();
          formData.append('semesterNum', semesterNum);
          formData.append('year', year);
          return AxiosService.post(API_ENDPOINT + adminUrl + '/addSemester', formData);
      }
      
      export const removeSemester = (id) => {
          return AxiosService.delete(API_ENDPOINT + adminUrl + '/removeSemester/' + id);
      }
      