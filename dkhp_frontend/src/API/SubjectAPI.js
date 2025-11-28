import { API_ENDPOINT } from "../Util/Constraint";
import AxiosService from "../Util/AxiosService";

const subjectUrl = '/subject/admin';

export const getAllSubjects = () => {
    return AxiosService.get(API_ENDPOINT + subjectUrl + '/getAllSubjects');
}

export const addSubject = (SubjectDTO) => {
    return AxiosService.post(API_ENDPOINT + subjectUrl + '/addSubject', SubjectDTO,true);
}

export const removeSubject = (id) => {
    return AxiosService.delete(API_ENDPOINT + subjectUrl + '/removeSubject/' + id);
}

